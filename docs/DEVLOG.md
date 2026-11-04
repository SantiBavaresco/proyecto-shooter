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

## F1.13 — Penetración de materiales y orden del código (2026-10-26)

### Funciona
- **Penetración**: chapa y madera se atraviesan según el espesor que la bala encuentra en su recorrido (un tiro en diagonal encuentra más material) y el poder del arma (daño × velocidad; fusil de asalto ≈ 1, pistola ≈ 0,3, perdigón ≈ 0,15, cerrojo .308 ≈ 2). Con poder 1: ~7 cm de madera o ~5 mm de chapa.
  - Sale del otro lado más lenta (pega menos) y apenas desviada; agujero y polvo/chispas en la entrada y en la salida.
  - Hasta 3 materiales por bala. Concreto, tierra y cuerpos no se atraviesan (todavía).
- **Estación de penetración** a la izquierda del polígono, afuera del muro (no tapa ningún carril): madera 2 cm, chapa 1 mm, chapa 4 mm y viga de 20 cm, con una diana de papel detrás de cada panel.
- **Código**: `WeaponController` quedó solo con la lógica (estados, disparo, recarga, fallas, munición, interacción; ~690 líneas) y la vista pasó a `WeaponViewmodel` (modelo, manos, pose, balanceo, retroceso visual, recargas animadas, visor; ~670 líneas), que solo lee el estado. Así los enemigos de F3 podrán usar la lógica de disparo sin la vista.
- 90 tests (3 nuevos de penetración).

## F1.14 — Ajustes de recarga con estrés, escopetas y cerrojos (2026-10-26)

### Funciona
- **Brazo izquierdo con estrés**: el balanceo de las manos al recargar ya no usa la amplificación del extremo y el giro del arma tiene tope; el brazo (y el hombro) no cruzan la pantalla.
- **Intentos al brocal por probabilidad**: cada intento puede fallar (medio 35 %, alto 55 %, extremo 70 %) con un máximo de intentos: medio 2, alto 3, extremo 4; pistolas hasta 3. Ya no es siempre la misma cantidad.
- **Escopetas**: las vainas saltan más rápido y casi verticales; las que caen al piso ahora son vainas de escopeta (tubo rojo con culote de latón), no casquillos de fusil.
- **Cerrojos y SK-45 (cartucho a cartucho)**: el contador sube con cada cartucho que entra; apretar el gatillo corta la recarga, cierra el cerrojo y queda listo con los que ya entraron.
- 91 tests.

## F1.15 — Respiración con visor (2026-10-26)

### Funciona
- Con visor, el rifle se mece lento por la respiración (más parado que agachado, más moviéndose y con estrés) y la retícula se mueve sobre el blanco.
- Apuntando, la bala sale por el eje del arma (respiración y pulso incluidos): donde está la retícula, no el centro fijo de la pantalla.
- **Shift con visor: aguantar la respiración** (5 s; 3 s en estrés alto). Calma: casi quieto. Estrés alto: la mitad (no es 100 % preciso). Estrés extremo: no se puede. Si se agota, 3 s "sin aire" con más balanceo; el aire se recupera soltando Shift. En el HUD: "AGUANTANDO LA RESPIRACIÓN n s" / "SIN AIRE".
- Con visor, Shift no corre; con miras abiertas sigue corriendo (y cancela el apuntado) como antes.
- 93 tests (2 nuevos).

## F1.16 — Escopetas: mira, estrés y quiebre (2026-10-26)

### Funciona
- **Yuxtapuestas (larga y recortada)**: al apuntar ya no tapan la mira. La palanca de apertura quedó por debajo de la línea de mira y el guion es más alto sobre la banda (como en la superpuesta); la mano derecha toma un poco más abajo.
- **Recarga de escopetas con estrés**: más lenta y, como el cargador en el brocal, los cartuchos pueden pegar en el borde de la recámara (medio hasta 2 intentos, alto 3, extremo 4, por probabilidad); la mano que carga tiembla.
- **Quiebre más rápido**: abre seco (~0,1 de la recarga en vez de 0,16) y cierra de golpe; las vainas saltan antes.
- 94 tests.

## F1.17 — Observaciones de prueba (2026-10-26)

### Funciona
- **SK-45**: siempre carga con peine (cargador fijo, como la real), aunque le queden cartuchos; la mano empuja una vez en vez de cartucho por cartucho.
- **Cerrojos**: más daño (R-700 110, Argentino 1909 100: un tiro al torso tumba). Nueva falla de extracción (la vaina no sale y el cerrojo queda trabado; R lo fuerza).
- **"No disparó"**: el cartucho se descuenta cuando sale al destrabar (antes se descontaba al apretar el gatillo y parecía que no salía nada).
- **KR-25** color arena con bípode plegado; ya no se confunde con el M-14E negro.
- **Zona de armas gastadas** más razonable (estado 35 % en vez de 18 %: ~1 falla cada 30 tiros) y las armas de mecanismo tipo AK (AR-74, AR-M, DR-1, PP-B, SK-45) fallan casi la mitad; los cerrojos, algo menos.
- 96 tests.

## F1.18 — Prueba de arma importada (.glb) (2026-10-26)

### Funciona
- **Carabina AR-74K** (modelo "AK74U | FREE ANIMATION." de BURNER, CC-BY 4.0) como arma inicial del slot 1: arma, brazos y animaciones del archivo (sacar, quieta, disparo, recarga, recarga vacía con montar, guardar).
- Soporte general para armas importadas (`entities/weapons/imported_weapon.gd`): la mira, la boca y la ventana se ubican sobre el hueso del arma; al apuntar, la línea de mira se alinea con la cámara cada cuadro (el archivo no trae animación de apuntar).
- Encima de la animación siguen todas las mecánicas: balanceo, retroceso, estrés (desenfoque, pulso, deriva, temblor), recarga más lenta con estrés y olvido de montar (usa la recarga corta), fallas por desgaste y destrabado (el tramo de montar de la recarga vacía), penetración.
- El FMR sigue en la armería; los tests de armas básicas lo equipan explícitamente.
- Se hizo en la rama `f1.18-glb-ak74u`: volver a la 1.17 es descartar la rama.
- 96 tests.

### Limitaciones de este modelo
- Con estrés, la recarga es más lenta pero no muestra los intentos fallidos al brocal (la animación es fija).
- No hay vaina trabada visible al encasquillarse (el aviso sí).
- Los brazos tienen piel y buzo gris (no los guantes del resto).


## F1.19 — Brazos del .glb para todas las armas y estrés en la recarga importada (2026-10-27)

### Funciona
- **Brazos con esqueleto en todas las armas** (`entities/weapons/skinned_arms.gd`): los brazos y manos del modelo del AR-74K (Mixamo, CC-BY) reemplazan a los guantes hechos por código en las 25 armas por código.
  - Las manos procedurales siguen existiendo y animándose igual (recargas, manija, cerrojo, cartuchos, destrabados), pero ocultas: son los objetivos. Cada cuadro la mano del esqueleto va a la mano procedural visible y el codo y el hombro se acomodan solos (IK de dos huesos, el codo cae abajo y afuera; si la mano no llega, el hombro acompaña).
  - Calibración: en el AR-74K se mide dónde queda cada mano respecto de la empuñadura y del guardamanos, y en cada arma se usa la misma relación sobre su empuñadura (con su ángulo y grosor) y su guardamanos (con su radio). Manija, corredera, mano de apoyo de pistola y mano con cartuchos de escopeta tienen su propia toma.
  - Al pasar de una toma a otra (empuñadura → manija) la mano viaja en 0,09 s en vez de saltar.
  - Los dedos quedan con la pose de agarre del modelo.
- **AR-74K con estrés: intentos fallidos al brocal.** La animación se maneja a mano (tiempo propio): con estrés el cargador llega al brocal, pega, vuelve un poco y reintenta, con golpe del arma y sonido en cada intento. Misma probabilidad y tope que el resto (medio 1, alto 2, extremo 3; 35/55/70 %). El olvido de montar sigue igual.
- 97 tests (nuevo: intentos fallidos de la recarga importada).

### Limitaciones
- Los dedos no se cierran distinto según lo que agarran (misma pose de agarre en todas las tomas).
- La mano con el cargador lo lleva al costado de la palma, no entre los dedos.
- Los brazos son de piel con buzo gris para todas las armas.

## F1.20 — Mano derecha, mira del AR-74K y disparos por calibre (2026-10-28)

### Funciona
- **Mano derecha**: el índice se cierra y se apoya en la cola del disparador (en el modelo estaba estirado por arriba del guardamanos del gatillo). La mano baja y abraza la empuñadura en vez del cajón; si el índice no llega al gatillo, la mano se acerca. En culatas de garganta (SKS, Mauser, escopetas, cerrojos) la mano no se acuesta del todo y sube a abrazar la garganta. Más corrida a la derecha en empuñaduras gruesas, para que el pulgar no las atraviese.
- Pistolas: se sacó el corrimiento a la derecha que tenía la mano.
- **Mira del AR-74K**: la línea de mira pasa por el alza y la punta del guion (el alza es más alta que el guion: antes tapaba el punto de impacto). La bala va a la punta del guion.
- **Disparos por calibre**: 11 calibres (.22 LR, 9×18, 9×19, .45 ACP, 5,45×39, 5,56×45, 7,62×39, 7,62×51/.308, 7,62×54R, 7,65×53, 12/70), 3 variantes cada uno, generados con `tools/audio/gen_gunshots.py`: onda de presión, ráfaga de gases, cuerpo grave, crack supersónico en los de fusil, saturación suave, rebote en el suelo, cola de reverberación que se oscurece y ecos lejanos. Cada disparo elige una variante con un poco de variación de tono y volumen; las colas se superponen al tirar en ráfaga.
- `tests/screenshots/hands_probe.gd`: vistas laterales de la toma de las manos (calibración).
- 97 tests (el de la armería ahora verifica que cada arma tenga el sonido de su calibre).

## F1.21 — Disparos menos "pandereta", sin zumbido de rebote, fogonazos variados (2026-10-28)

### Funciona
- **Disparos rehechos** (`tools/audio/gen_gunshots.py`): sin rebote en el suelo ni ecos que repetían el golpe (daban el sonido metálico de pandereta y demasiado eco); cola de ambiente corta y oscura.
  - Pistolas y .22: golpe seco de medios ("pop"), sin siseo agudo; el .22 corto y seco.
  - Fusiles largos: retumbe grave que rueda y se apaga lento; más largo en los de cerrojo (.308 propio para el R-700, 7,65×53, 7,62×54R).
- Se sacó el zumbido de los rebotes (sigue rebotando la bala; el sonido del impacto en acero suena más corto).
- **Fogonazos**: 6 estrellas distintas (cantidad y largo de puntas, núcleo irregular), más una llama hacia adelante de largo variable (a veces no aparece), tamaño, color y brillo distintos en cada disparo; se achica en los cuadros que dura.
- `armory_shots --fogonazos`: capturas de varios disparos seguidos.

### Pendiente
- Sonidos grabados reales: el entorno no puede descargar de opengameart/freesound. La biblioteca CC0 "The Free Firearm Sound Library" es candidata si se adjuntan los archivos.

## F1.22 — Vuelven los disparos de la F1.20 (2026-10-28)
- Los disparos rehechos en la F1.21 no gustaron: vuelven los de la F1.20 (`gen_gunshots.py` y los WAV de esa versión). Se mantienen sin zumbido de rebote y los fogonazos variados.

## F1.23 — Modelos .glb de armas, personajes de prueba y props (2026-10-29)

### Funciona
- **Armas con modelo .glb** (`entities/weapons/glb_weapon.gd`): el modelo reemplaza la geometría por código pero conserva todo lo demás (piezas Mag/Charging/Bolt/Crane, marcadores, manos con esqueleto, recargas, fallas). Las armas que traen huesos por pieza (M14, XM2010) se pasan a mallas fijas por hueso al cargar. Calibración con `tests/screenshots/_calib.gd` (vistas ortográficas con grilla).
  - Reemplazos: Fusil AR-M (modelo AKMN), Fusil M-14E (modelo M14, con el visor montado sobre el riel).
  - Nuevas: Fusil AR-47 (AK-47), Subfusil VK-19 (Vityaz, con holográfico), Subfusil ST-2 (STEN, cargador al costado), Subfusil PT-91 (Pleter 91), Subfusil casero AC-9 (Andrews, cargador al costado), Rifle R-700 SR (XM2010, variante del R-700) y Revólver RS-6 .45.
  - Revólver: recarga propia: el tambor sale a la izquierda, la varilla expulsa las 6 vainas, la mano trae los cartuchos todos juntos y cierra. Con estrés los cartuchos pegan en el borde y reintenta (igual que la escopeta). Si no dispara, se gatilla de nuevo.
  - Cargadores al costado (STEN, AC-9): la recarga los saca hacia la izquierda.
  - Armería con 33 armas (6 columnas).
- **Personajes de prueba** (`world/props/npc_dummy.gd`): FSB, SWAT (3 versiones) y policía sci-fi en fila a 18 m. Zonas por hueso (cabeza con núcleo letal, torso, extremidades), número de daño, y al morir caen tiesos como una tabla hacia donde los empujó el tiro (rebotan apenas contra el piso); a los 4 s se paran. Sin visores nocturnos donde el visor es una pieza aparte (FSB, SWAT).
- **Cajas y barriles** (.glb) con colisión exacta cerca de la línea de tiro.
- .22 más agudo (solo se regeneró ese calibre).
- Las escenas .glb se cargan una vez y quedan en memoria (cada arma o personaje nuevo no relee el disco).

### No se usó
- FAL ("Parafal"): 703 triángulos y textura de 256 px, se ve peor que el FMR por código.
- PMC ("BPRE Rifleman"): el archivo viene roto (el esqueleto no coincide con la malla; también en los datos originales).
- El SWAT "Special Remaster" tiene el visor nocturno pegado a la malla del casco: no se puede sacar sin editar el modelo.

## F1.24 — Vuelven de verdad los disparos de la F1.20 (2026-10-29)
- Bug: al volver a los WAV de la F1.20 (F1.22) se sacaron de git como punteros de Git LFS (texto de 130 bytes) porque el repositorio no tenía los filtros de LFS instalados; el juego no los podía cargar y usaba el disparo sintético viejo. Se restauraron los archivos reales (iguales al demo de la F1.20, comprobado muestra por muestra) y se instaló LFS en el repo (`git lfs install --local`).
- El test de la armería ahora verifica que cada variante de disparo sea audio de verdad (no un puntero).
- Texturas de los modelos .glb comprimidas para la placa de video (S3TC): antes iban sin comprimir (≈4 MB de memoria de video cada una de 1024 px).

## F1.25 — Limpieza de modelos (2026-11-02)
- Se sacaron el Fusil AR-47 (modelo de 500 mil triángulos) y el policía sci-fi de la fila de personajes. El AR-M sigue con el modelo AKMN.
- El Subfusil VK-19 ya no usa el .glb: tiene modelo propio por código (tipo PP-19-01 Vityaz): cajón de AK-74, culata tubular plegable con tope de goma, caño de 237 mm con apagallamas, guardamanos con rieles a los costados, cargador recto de 9×19 y **mira holográfica** de caja (ventana rectangular con anillo y punto, nuevo modo del shader del punto rojo).
- Armería con 32 armas. El juego pesa ≈65 MB menos.

## 2.0 / F2 — Inventario estilo STALKER 2 (2026-11-02)

### Funciona
- **Inventario (Tab)**: mochila en grilla de 12×10 con peso. Equipo: Arma 1, Arma 2, Pistola, Casco, Chaleco, Mochila. Cuatro **ranuras rápidas** (teclas 5–8) para consumibles. Plata en USD.
  - Arrastrar y soltar (R gira mientras se arrastra; soltar afuera de los paneles = tirar al suelo). Clic derecho: usar, equipar, desequipar, descargar, dividir, asignar a ranura rápida, tirar. Doble clic: usar / equipar / pasar. Mayús+clic: pasar entre mochila y contenedor. Botón Ordenar.
  - Ficha del ítem con sus datos; las armas se comparan con la equipada (daño, cadencia, cargador, precisión, en verde/rojo).
  - Íconos sacados de los modelos 3D reales de cada ítem (las armas, de costado).
  - El mundo no se pausa con el inventario abierto (como en STALKER 2), pero el jugador no se mueve ni dispara.
- **Munición por calibre en la mochila**: las armas del mismo calibre la comparten y la recarga la saca de ahí (.308 y 7.62×51 son la misma). Descargar un arma devuelve los cartuchos.
- **Armas como ítems**: guardan su cargador, desgaste, modo de disparo y fallas al desequiparlas. Sin armas equipadas se queda con las manos vacías.
- **Peso**: 40 kg sin penalidad (+10/+20 con mochila chica/grande, +5/+10 con chaleco). Arriba de eso se camina más lento y correr y saltar cansan más; pasando 20 kg más no se puede correr ni saltar.
- **Salud y sangrado** (HUD abajo a la izquierda, viñeta roja con poca salud o al recibir daño). Morir reinicia el nivel (el guardado llega en F7).
- **Consumibles** con tiempo de uso (el arma baja mientras tanto): venda, botiquín, botiquín militar, energizante, agua, carne en lata, pan. Barra "Usando" en el HUD.
- **Saqueo** en ventana doble: cajón de madera (al azar), caja metálica, alijo, caja de munición (ahora es un contenedor que se repone al abrirlo) y **cuerpos** de los personajes de prueba (su arma, munición y botín; se paran recién cuando cerrás la ventana). "Tomar todo".
- **Ítems sueltos** en el piso: [F] para agarrarlos; lo que tirás cae con física.
- Laboratorio: zona "Inventario y saqueo" atrás a la izquierda del spawn con contenedores, ítems sueltos y **alambre de púas** (lastima y hace sangrar).
- Las mesas de la armería siguen (equipan directo y dan munición) para probar armas rápido.

### Decisiones
- Munición total por calibre (como pide el plan); cargadores individuales a futuro.
- Cascos y chalecos guardan su protección pero recién cuenta con el daño al jugador de la F3.
- Hambre, sed y sueño: F5. Comercio y reparación: F6.

## 2.0.1 — Equipo reacomodado (2026-11-03)
- Inventario: Arma 2 a la izquierda y Arma 1 a la derecha (paradas, caño arriba), casco, chaleco y mochila al centro, pistola debajo del Arma 2 y la nueva ranura de **arma blanca** debajo del Arma 1.
- Nuevo ítem: cuchillo de combate (viene equipado). El ataque cuerpo a cuerpo (V) llega más adelante.

## 2.0.2 — Correcciones de armas e inventario más grande (2026-11-03)

### Armas
- **AR-74K**: la recarga no se veía. La animación se manejaba a mano con velocidad 0 y arrancaba con un fundido de 0,12 s que nunca avanzaba: el modelo se quedaba en la pose quieta. Ahora arranca sin fundido.
- **ST-2**: la línea de mira pasaba por debajo del agujero del alza (es de anillo). Ahora pasa por el centro del anillo y el guion se subió 4 mm para quedar alineado.
- **AC-9**: la mira estaba 8 mm por encima de las miras reales; bajada a la altura de alza y guion.
- **ST-2 y AC-9**: al recargar, la muñeca izquierda gira para agarrar y meter el cargador de costado.
- **PT-91**: el cierre (con su manija) va y viene en cada disparo. También la manija de toda la familia AK por código.
- **AR-M**: la mira apuntaba a lo alto del arco del guion; bajada al poste.
- **R-700 SR**: más adelante en la cadera, ocular más lejos del ojo y el vidrio del visor centrado en el tubo (estaba 3,5 mm arriba).
- **Visores**: desde la cadera el ocular muestra lo que ve el visor, pero chico, corrido según el ángulo, deformado y borroso (como un visor lejos del ojo). Se actualiza a medio ritmo para no costar tanto.
- **SK-45**: con peine, los cartuchos entran de a uno con un empujón del pulgar cada uno (el contador sube de a uno).
- Herramienta de datos: `set_params.py` cortaba mal el bloque `model_params` (diccionarios anidados) y dejaba restos viejos en los .tres; arreglado y archivos limpios (el juego ya leía el bloque correcto).

### Inventario
- Celdas al doble (92 px en 1920×1080). Mochila de 8×15 con desplazamiento (rueda o arrastrando al borde); contenedores de hasta 8 columnas.
- Revisando una caja o un cuerpo, mochila y contenedor quedan lado a lado (el equipo se oculta, como en STALKER 2).
- **E: tomar todo** del alijo, caja o cuerpo.
- Teclas propias de la pantalla de inventario, configurables en Opciones → Controles → Pantalla de inventario: tomar todo (E), girar (R), ordenar (T), usar / equipar el ítem señalado (F) y pasar al otro lado (Mayús + clic). No chocan con las del juego.

## 2.0.3 — Ajustes (2026-11-03)
- ST-2 y AC-9: el giro de muñeca de la 2.0.2 dejaba la mano dada vuelta hacia arriba. Ahora es un giro de 35° hacia el otro lado (la mano agarra el cargador por detrás), configurable por arma (`side_mag_wrist` en model_params).
- R-700 SR: vidrio del visor 1 mm más abajo; ya queda centrado en el ocular.

## 2.0.4 — Agarre del cargador lateral, vainas que quedan y expulsión de escopeta nueva (2026-11-03)
- ST-2 y AC-9: la mano agarra el cargador por arriba (nudillos arriba, dedos envolviéndolo), con el antebrazo viniendo de atrás a la izquierda. La orientación se calculó para esa pose y es configurable por arma (`side_mag_hand`, euler YXZ).
- Vainas: rebotan poco y casi no ruedan (más fricción y frenado del giro; en pendiente siguen bajando). Cuando quedan quietas dejan de ser cuerpos físicos y pasan a una lista que se dibuja de una sola vez (MultiMesh): duran 4,5 minutos y se ven hasta 150 m. Máximo 600 por tipo (las más viejas se van). Costo casi nulo.
- Escopetas: la expulsión se rehízo. Antes las vainas se animaban dentro de la vista del arma y subían 20 cm delante de la cámara (se veían enormes, flotando) y además salían las vainas físicas. Ahora el extractor las saca un poco al abrir y enseguida saltan como vainas reales hacia arriba y atrás, por encima de la cabeza, y caen detrás. No chocan con el jugador.

## 2.0.5 — Objetos del piso más grandes (2026-11-03)
- Los ítems sueltos en el mundo (vendas, botiquines, comida, munición, equipo, plata) se ven al doble y su caja para agarrarlos también; las armas siguen a escala real. Los íconos del inventario no cambian.
