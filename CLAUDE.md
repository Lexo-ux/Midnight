# Medianoche en Much (proyecto LifeSim)

Juego de misterio en bucle para Android, hecho en **Godot 4.7 (GDScript)**. Documento de diseño (fuente de verdad de historia, personajes, mundo y tono): `docs/medianoche_en_much_design.md`. Si una tarea contradice el documento, manda la tarea.

## Concepto
- El mismo día se repite en la ciudad de Much. Dos protagonistas: **Sazil** (civil, cartera; ve a la gente, fuerte de día) y **Akba** (Despertado, vigilante nocturno; ve el Umbral, fuerte de noche).
- El jugador puede cambiar de uno a otro cuando quiera, sin coste. Quien no se controla sigue su rutina.
- La única progresión es el **Cuaderno del Umbral** (lo que se sabe sobrevive a medianoche). Los habitantes empiezan como siluetas (Velo).
- Corte vertical actual (Task 03): de 14:00 a 24:00, con Relojería, Mercado y Plaza; Ruth, Lina, Tun, Marcos y Beto; finales «Otra vez» y «Un buen día».
- El estudio solo hace las siluetas; la comunidad diseña los retratos. No se usan glifos ni símbolos sagrados mayas.

## Reglas del proyecto
- Todo el código en GDScript, tipado cuando se pueda (`var x: int`; Godot trata como error inferir el tipo desde un `Variant`).
- Todo el texto (historia, diálogo y también los textos de la interfaz) va en JSON dentro de `data/`, NUNCA en el código.
- Una escena = una responsabilidad. Escenas en `scenes/`, scripts en `scripts/` con el mismo nombre que la escena.
- Nombres: archivos y carpetas en `snake_case`, clases en `PascalCase`.
- Pantalla vertical, una mano, áreas táctiles de 120 px o más, fuente de 40 o más. Renderer: Compatibility.
- No tocar la carpeta `android/` ni `export_presets.cfg` salvo que la tarea lo pida.

## Estructura
```
data/         settings, locations, npcs, events, clues, endings, letters, ui_text (JSON)
data/dev/     recorridos guionizados de los finales (para los tests)
scripts/      game_data (carga y valida), simulation (motor), game_state (autoload), save_manager, UI
scripts/dev/  run_tests.gd, tests/, loop_validator.gd, validate_loops.gd
scenes/       main (diorama) y componentes: tarjeta de lugar, silueta, selector, diálogo, Cuaderno, herramientas, ajustes, medianoche
assets/       silhouettes/*.svg (cuerpo en rojo puro, rasgo en verde puro: el shader los tiñe), shaders/
docs/         documento de diseño
```

## Arquitectura
- **Quién manda.** `scripts/game_state.gd` (autoload `GameState`) es la única fuente de verdad. Tiene las acciones (`perform`, `switch_to`, `skip_to`, `replay_route`, `start_next_loop`, `reveal_hint`, ajustes) y la señal `changed`. La UI solo lee, llama acciones y se redibuja. Nunca guarda estado de juego.
- **Motor** (`scripts/simulation.gd`): determinista, sin azar, todo el estado del bucle en un `Dictionary`. Si algún día se añade variación (frases de ambiente), irá en un PRNG con semilla por bucle y un flujo separado por dominio.
- **Reloj del mundo compartido.** Cada acción (observar, hablar, seguir, esperar, cartas, forzar, sellar…) cuesta 30 minutos para todos. Cambiar de protagonista cuesta 0. Actuar en un lugar lleva allí al protagonista. La hora de inicio del bucle es `settings.loop_start`.
- **Un paso:**
  1. Se aplica la acción.
  2. El otro protagonista hace su rutina (Sazil reparte).
  3. Avanza el reloj y todos se colocan según su rutina (`routine`: tramos con `from`, `if` y `override`).
  4. Se evalúan una sola vez los eventos de esa hora.
  5. A medianoche se decide el final.
- **Estado.** Del bucle (se reinicia): hora, protagonista activo, posiciones, banderas con hora, cartas, Rastro, Desgaste, ruta grabada. Permanente: Cuaderno, Velo, finales vistos, pistas pedidas, ajustes, ruta del bucle anterior.
- **Regla de causalidad.** Las condiciones se evalúan en el momento en que algo ocurre. Una bandera solo afecta a lo que aún no ha ocurrido; lo ya vivido nunca se reescribe. `flag_earlier` exige que la bandera se activara en un paso anterior.
- **Rastro y Desgaste** (`settings.json`):
  - Rastro medio (3): Marcos adelanta la patrulla a las 19:00. Rastro alto (6): va a donde esté Akba.
  - Forzar o sellar de día cuesta el doble de Desgaste. Con el Desgaste lleno, Akba solo puede esperar el resto de la hora.
- **Guardado** (`scripts/save_manager.gd`, `SAVE_VERSION` 2): `user://savegame.json` tras cada acción, cambio e inicio de bucle. Al arrancar se valida todo contra los datos; si no vale (incluida la versión 1 del prototipo), avisa y empieza de cero.
- **Datos** (validados por `scripts/game_data.gd`, con errores en español):
  - Condiciones: una bandera, o `{ALL|ANY|NOT|clue|at|together|was_at|rastro_min|rastro_max|letter|night|interior|time_from|time_to|flag_earlier}`.
  - Los Horario del Cuaderno se generan desde los tramos `schedule` de las rutinas.
  - Toda bandera que se comprueba se activa en algún sitio, y al revés.
  - Las preguntas abiertas solo miran pistas.

## Cómo validar
- Que el proyecto abra sin errores: `godot --headless --path . --quit`
- Tests: `godot --headless --path . --script res://scripts/dev/run_tests.gd`. Imprime PASS/FAIL por test y sale con 1 si algo falla; tarda alrededor de 1,5 min. El fuzz imprime la semilla de cualquier fallo.
  - Los ERROR/WARNING que salen durante los tests de datos y de guardado son esperados: esos tests rompen cosas a propósito.
- Validador de bucles: `godot --headless --path . --script res://scripts/dev/validate_loops.gd`. Comprueba referencias y que todas las pistas de la ventana y todos los finales sean alcanzables (búsqueda en anchura con el mismo motor), y escribe `build/clue_graph.md` (Mermaid). También corre dentro de los tests.
- Probar en el celular con "Ejecutar en el dispositivo" desde Godot (debug keystore ya configurado).

## Tareas
- Se trabajan como "Tasks" numeradas. Cada Task: objetivo, archivos que toca, y cómo se comprueba.
- Tasks 01-02: prototipo técnico (retirado). Task 03: corte vertical de Medianoche en Much. Task 04 (siguiente): conversaciones con cartas, quiebre de mantener pulsado, Velo 2-3.

## Git
- Por ahora se trabaja en `main` (remoto `origin`: github.com/Lexo-ux/Midnight). Nunca force-push ni reescribir historia.
- Un commit al terminar cada Task numerada: `feat: Task NN <nombre>`.
- Nunca commitear `build/`, `.godot/`, `android/`, keystores ni `.claude/settings.json`.
