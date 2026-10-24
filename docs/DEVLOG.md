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
