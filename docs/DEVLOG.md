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
