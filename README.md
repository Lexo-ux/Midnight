# Medianoche en Much

Juego de misterio en bucle para Android. El mismo día se repite en la ciudad de Much, y solo dos vidas pueden romperlo juntas: Sazil, que reparte el correo y ve a la gente, y Akba, un Despertado que vigila de noche y ve el Umbral. Se puede cambiar de uno a otro en cualquier momento; quien no se controla sigue su rutina. Lo único que sobrevive a medianoche es el Cuaderno del Umbral: lo que se sabe.

## Estado actual

Corte vertical (Task 03): de 14:00 a medianoche, con la Relojería, el Mercado y la Plaza; Ruth, Lina, Tun, Marcos y Beto; y dos finales, «Otra vez» y «Un buen día». Aún no se ha probado a fondo en un teléfono.

## Abrir el proyecto

1. Instala **Godot 4.7.x** (versión estándar, no .NET).
2. En el gestor de proyectos, importa `project.godot`.
3. Para exportar a Android, instala antes las plantillas de exportación de Godot 4.7 y configura el SDK y el keystore de depuración en *Editor > Configuración del editor*. La carpeta `android/` (plantilla de Gradle) no se versiona: si hace falta, se regenera con *Proyecto > Instalar plantilla de compilación de Android*.

## Tests y validador

Que el proyecto abra sin errores:

```
godot --headless --path . --quit
```

Tests (unos 1,5 min; los ERROR/WARNING de los tests de datos y guardado son esperados):

```
godot --headless --path . --script res://scripts/dev/run_tests.gd
```

Validador de bucles (comprueba que todas las pistas y finales sean alcanzables y escribe `build/clue_graph.md`):

```
godot --headless --path . --script res://scripts/dev/validate_loops.gd
```

En un clon nuevo, ejecuta primero `godot --headless --path . --import` para generar `.godot/`.

## Carpetas

```
data/     contenido en JSON: lugares, personas, eventos, pistas, finales, cartas y textos de la interfaz
scripts/  motor (simulation), estado (game_state), carga y validación de datos, guardado e interfaz
          scripts/dev/: tests, validador de bucles
scenes/   el diorama principal y sus componentes
assets/   siluetas SVG y shaders
docs/     documento de diseño
```

El documento de diseño, fuente de verdad de la historia, los personajes y el tono, está en `docs/medianoche_en_much_design.md`. Las reglas de trabajo del proyecto están en `CLAUDE.md`.
