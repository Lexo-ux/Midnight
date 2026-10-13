# Medianoche en Much (proyecto LifeSim)

Juego de misterio en bucle para Android, hecho en **Godot 4.7 (GDScript)**. Documento de diseño (fuente de verdad de historia, personajes, mundo y tono): `docs/medianoche_en_much_design.md`. Si una tarea contradice el documento, manda la tarea.

## Concepto
- El mismo día se repite en la ciudad de Much. Dos protagonistas: **Sazil** (civil, cartera; mujer joven; ve a la gente, fuerte de día) y **Akba** (Despertado, vigilante nocturno; hombre, con un colgante poliédrico que brilla; ve el Umbral, fuerte de noche).
- El jugador puede cambiar de uno a otro cuando quiera, sin coste. Quien no se controla sigue su rutina.
- La única progresión es el **Cuaderno del Umbral** (lo que se sabe sobrevive a medianoche). Los habitantes empiezan como siluetas (Velo).
- Corte vertical actual (Task 03): de 14:00 a 24:00, con Relojería, Mercado y Plaza; Ruth, Lina, Tun, Marcos y Beto; finales «Otra vez» y «Un buen día».
- Presentación (Task 05): cada lugar es una escena en primera persona (solo se ven las manos) por la que se avanza con las acciones; el mapa lleva de un lugar a otro.
- Task 04: conversaciones con cartas (Lina, Tun, Beto, Ruth; Marcos sigue guionizado), momentos de quiebre de mantener pulsado (15:00 Lina, 21:00 Plaza), Velo 2-3 (rostro y retrato), sonido, vibración y pulido (consejos, «¿Qué hago?», botón atrás de Android).
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
data/         settings, locations, npcs, events (+ breakpoints), clues, endings, letters, ui_text, scenes, art_manifest,
              cards (reglas, cartas y conversaciones), audio + audio_manifest, haptics (JSON)
data/dev/     recorridos guionizados de los finales (para los tests)
scripts/      game_data (carga y valida), simulation (motor), conversation (reglas de las cartas), sustain_controller
              (sostener), game_state, audio_director, haptics (autoloads), save_manager, scene_rules, art_library, UI
scripts/dev/  run_tests.gd, tests/ (+ tests/slow/), loop_validator.gd, validate_loops.gd, ingest_art.gd (+ art_ingest.gd),
              make_placeholder_audio.gd
scenes/       main (escena del lugar) y componentes: place_view, mapa, silueta, selector, diálogo, Cuaderno, herramientas,
              ajustes, medianoche, conversación, quiebre, consejos
assets/       art/ (arte final), art_incoming/ (en bruto, ignorado), silhouettes/*.svg (cuerpo en rojo puro, rasgo en verde puro),
              shaders/, audio/ (sonido de verdad) y audio/placeholder/ (provisional, sintetizado)
docs/         documento de diseño, art_pipeline.md, haptics.md, screenshots/
```

## Arquitectura
- **Quién manda.** `scripts/game_state.gd` (autoload `GameState`) es la única fuente de verdad. Tiene las acciones (`perform`, `switch_to`, `skip_to`, `replay_route`, `start_next_loop`, `reveal_hint`, `next_hint`, conversaciones, quiebres, ajustes) y la señal `changed`. La UI solo lee, llama acciones y se redibuja. Nunca guarda estado de juego.
- **Autoloads.** `GameState`; `AudioDirector` (`scripts/audio_director.gd`: buses Master/Music/Ambience/SFX, sucesos de `data/audio.json` → sonidos de `data/audio_manifest.json`; el de verdad en `assets/audio/<id>.ogg|wav|mp3`, si no el provisional, si no silencio y un aviso; sin salida de audio no falla); `Haptics` (`scripts/haptics.gd`, patrones de `data/haptics.json`, `Input.vibrate_handheld`, niveles off/low/normal; ver `docs/haptics.md`). Los tests que usan la escena principal apagan antes el autoguardado del autoload.
- **Motor** (`scripts/simulation.gd`): determinista, sin azar, todo el estado del bucle en un `Dictionary`. Si algún día se añade variación (frases de ambiente), irá en un PRNG con semilla por bucle y un flujo separado por dominio.
- **Reloj del mundo compartido.** Cada acción (observar, hablar, seguir, esperar, cartas, forzar, sellar…) cuesta 30 minutos para todos. Cambiar de protagonista cuesta 0. Actuar en un lugar lleva allí al protagonista. La hora de inicio del bucle es `settings.loop_start`.
- **Un paso:**
  1. Se aplica la acción.
  2. El otro protagonista hace su rutina (Sazil reparte).
  3. Avanza el reloj y todos se colocan según su rutina (`routine`: tramos con `from`, `if` y `override`).
  4. Se evalúan una sola vez los eventos de esa hora.
  5. A medianoche se decide el final.
- **Estado.** Del bucle (se reinicia): hora, protagonista activo, posiciones, banderas con hora, cartas, Rastro, Desgaste, ruta grabada y estación de cada protagonista en cada lugar (solo presentación). Permanente: Cuaderno, Velo, finales vistos, pistas pedidas, ajustes, ruta del bucle anterior.
- **Escenas** (`data/scenes.json`, reglas puras en `scripts/scene_rules.gd`): cada lugar tiene un lienzo de 2880×1920 con 4-5 estaciones; cada acción lleva a la estación de lo que toca, y «esperar», a la siguiente. Mirar alrededor y abrir el mapa son gratis y no tocan la simulación. Los puntos interactivos son «observar» el lugar desde su estación, con mirada (`sazil`/`akba`/`both`) y ventana horaria. Las fisuras solo se ven con Akba.
- **Arte** (`data/art_manifest.json`, `scripts/art_library.gd`): ranuras por lugar (`bg_day/dusk/night`, `mid` opcional, `fg`, `akba_overlay` aditivo), retratos y manos. Si falta un archivo se dibuja un provisional y se avisa una vez. El arte nuevo se deja en `assets/art_incoming/<ranura>.png` y se prepara con `scripts/dev/ingest_art.gd` (ver `docs/art_pipeline.md`).
- **Regla de causalidad.** Las condiciones se evalúan en el momento en que algo ocurre. Una bandera solo afecta a lo que aún no ha ocurrido; lo ya vivido nunca se reescribe. `flag_earlier` exige que la bandera se activara en un paso anterior.
- **Conversaciones con cartas** (`data/cards.json`, reglas puras en `scripts/conversation.gd`): Lina, Tun, Beto y Ruth. 4 turnos, Confianza 0-5 (empieza en `confianza_inicial`), mano = 4 primeras del mazo (orden fijo) + una de Conocimiento por cada pista del Cuaderno con `opens_door` a una de sus puertas.
  - Escuchar descubre el siguiente muro o puerta. Verdad abre su puerta si sus muros están descubiertos o rotos y se cumple su `if`; si no, −1. Silencio no gasta turno (otra frase, a veces con pista). Presión rompe un muro, −1 (−2 si `fragile`). Revelar abre, convence o aterra según la persona. Conocimiento abre su puerta aunque haya muros. Recordar solo existe en los datos (gancho).
  - Confianza 0: la persona se cierra hasta el próximo bucle. Sin turnos: «otro rato», la Confianza se queda para el resto del bucle. Lo apuntado en el Cuaderno empieza descubierto.
  - Ganar con Akba usando Presión o Revelar es forzar: cuesta como `forzar` (`forced_rastro`), marca a la persona (Velo visible −1 y, el bucle siguiente, −1 de Confianza y una frase de miedo).
  - La UI juega la conversación sin tocar la partida; al terminar cuenta como una acción «hablar» de 30 minutos con la lista de cartas (`cards`), que la simulación vuelve a jugar. Sin cartas no cuesta nada. «Repetir mi ruta» juega las cartas grabadas mientras valgan (lo aprendido puede cambiar cómo acaba).
- **Momentos de quiebre** (`events.json`, `breakpoints`): envuelven interacciones (15:00 Lina: `tirar_de_lina`/`sostener_lina`; 19:00 y 21:00 Plaza: `interponerse`/`atraer_marcos`). Se sostienen con `scripts/sustain_controller.gd` (máquina de estados pura con reloj inyectado): mantener pulsado o tocar, 20 s, 40 s o sin tiempo (se elige una vez y se cambia en Ajustes); perder el foco pausa. La simulación solo recibe `decision` (`sostuvo`/`soltó`); «soltó» deja el mismo mundo que esperar allí.
- **Velo:** 0 silueta, 1 rasgos (horario completo), 2 rostro (ganar una puerta), 3 retrato (su secreto `velo3.secret` o salvarla, `velo3.saved_if` a medianoche). Lo visible es el ganado menos sus marcas. Caras en `npc_<id>_velo2/3` (provisionales dibujadas mientras la comunidad no las haga; `portrait_credit` sale en el Cuaderno). Los protagonistas enseñan su retrato.
- **Rastro y Desgaste** (`settings.json`):
  - Rastro medio (3): Marcos adelanta la patrulla a las 19:00. Rastro alto (6): va a donde esté Akba.
  - Forzar o sellar de día cuesta el doble de Desgaste. Con el Desgaste lleno, Akba solo puede esperar el resto de la hora.
- **Guardado** (`scripts/save_manager.gd`, `SAVE_VERSION` 4): `user://savegame.json` tras cada acción, cambio e inicio de bucle. Al arrancar se valida todo contra los datos. Se migran la versión 2 (sin estaciones) y la 3 (sin marcas, conversaciones ni ajustes nuevos; los temas guionizados que pasaron a conversaciones quedan en la ruta como «esperar» allí); si no vale (incluida la versión 1 del prototipo), avisa y empieza de cero. La versión 4 guarda marcas, Velo 2-3, conversaciones del bucle, cartas y decisiones en la ruta y los ajustes de sonido, vibración, quiebres y consejos.
- **Datos** (validados por `scripts/game_data.gd`, con errores en español):
  - Condiciones: una bandera, o `{ALL|ANY|NOT|clue|at|together|was_at|rastro_min|rastro_max|letter|night|interior|time_from|time_to|flag_earlier}`.
  - Los Horario del Cuaderno se generan desde los tramos `schedule` de las rutinas.
  - Toda bandera que se comprueba se activa en algún sitio, y al revés.
  - Las preguntas abiertas solo miran pistas.

## Cómo validar
- Que el proyecto abra sin errores: `godot --headless --path . --quit`
- Tests: `godot --headless --path . --script res://scripts/dev/run_tests.gd`. Imprime PASS/FAIL por test y sale con 1 si algo falla; tarda unos 2 min. El fuzz (300 partidas, con conversaciones, quiebres y ajustes al azar) imprime la semilla de cualquier fallo. Con `-- --slow` corren además las pruebas lentas (`tests/slow/`: que la abstracción del validador coincide con probar todas las secuencias de cartas).
  - Los ERROR/WARNING que salen durante los tests de datos, de guardado y de arte son esperados: esos tests rompen cosas a propósito, y el arte que falta avisa una vez por ranura.
- Validador de bucles: `godot --headless --path . --script res://scripts/dev/validate_loops.gd -- [--max-states N] [--timeout S]`. Comprueba referencias, que todas las pistas de la ventana, todos los finales y todas las puertas de conversación sean alcanzables (búsqueda en anchura con el mismo motor), que las pistas de Conocimiento se puedan conseguir y que cada punto interactivo revele su pista en su ventana, y escribe `build/clue_graph.md` (Mermaid). Imprime estados y segundos (unos 19 000 estados y ~35 s). También corre dentro de los tests.
  - **Nunca lo ejecutes sin límite**: envuélvelo en `timeout` y deja `--max-states` (2 000 000 por defecto) y `--timeout` (600 s); si se pasa, sale con 1 diciendo qué dimensión del estado creció más.
  - **Conversaciones abstraídas**: en la búsqueda nunca se prueban secuencias de cartas (no terminaba: más de 10 minutos). Cada conversación da 1-4 órdenes, una por efecto distinto (banderas nuevas, forzada o no), con `Conversation.solve()`/`listen()` en caché; lo que solo da pistas equivale a esperar allí; ganar a la fuerza no se explora si se puede lo mismo sin forzar; las puertas abiertas y la Confianza no entran en la clave (sus efectos ya están en las banderas). `tests/slow/test_conversation_abstraction.gd` comprueba que `solve()` da los mismos resultados que todas las secuencias.
- Probar en el celular con "Ejecutar en el dispositivo" desde Godot (debug keystore ya configurado).

## Tareas
- Se trabajan como "Tasks" numeradas. Cada Task: objetivo, archivos que toca, y cómo se comprueba.
- Tasks 01-02: prototipo técnico (retirado). Task 03: corte vertical de Medianoche en Much. Task 05: escenas, mapa, dos miradas, manos en primera persona y canal de arte. Task 04: conversaciones con cartas, quiebres de mantener pulsado, Velo 2-3, sonido, vibración y pulido.

## Git
- Por ahora se trabaja en `main` (remoto `origin`: github.com/Lexo-ux/Midnight). Nunca force-push ni reescribir historia.
- Un commit al terminar cada Task numerada: `feat: Task NN <nombre>`.
- Nunca commitear `build/`, `.godot/`, `android/`, keystores ni `.claude/settings.json`.
