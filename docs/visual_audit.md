# Auditoría visual (Task 06, bloque 0)

Rama de partida: `task-04-conversaciones` (fa44294). Capturas «antes» hechas con
`scripts/dev/capture_screens.gd` (xvfb + Compatibility, 1080×1920, texto Normal y
Muy grande, y ventana corta 1080×1600). Las de este documento están en
`docs/screenshots/task-06/before/`.

**Medida táctil.** El lienzo lógico mide 1080 px de ancho en cualquier teléfono
vertical (`canvas_items` + `expand`). En un Android de 360 dp de ancho (el más
estrecho habitual, p. ej. la serie Galaxy A/S con el tamaño de pantalla por
defecto) eso es 3 px lógicos por dp, así que **48 dp = 144 px**. Todo lo que hoy
mide 120 px son 40 dp. En teléfonos más anchos (411 dp) 144 px son 56 dp.

## 1. Ranuras de arte

Estado: **real** (archivo de Alex en `assets/art/`), **falta** (se dibuja un
provisional en código y se avisa una vez), **comunidad** (lo hace la comunidad,
no el estudio: no se genera nada).

| Ranura | Ruta | Tipo | Tamaño (proporción) | Si falta | Estado |
| --- | --- | --- | --- | --- | --- |
| `relojeria_bg_day/dusk/night` | `places/relojeria/bg_*.jpg` | opaco | 2880×1920 (3:2) | provisional | real |
| `relojeria_mid` | `places/relojeria/mid.png` | recorte | 2880×1920 (3:2) | nada sobre fondo real | falta (opcional) |
| `relojeria_fg` | `places/relojeria/fg.png` | recorte | 2880×1920 (3:2) | provisional | **falta** |
| `relojeria_akba_overlay` | `places/relojeria/akba_overlay.jpg` | aditivo | 2880×1920 (3:2) | provisional | real |
| `mercado_bg_day/dusk/night` | `places/mercado/bg_*.jpg` | opaco | 2880×1920 (3:2) | provisional | real |
| `mercado_mid` | `places/mercado/mid.png` | recorte | 2880×1920 (3:2) | nada sobre fondo real | falta (opcional) |
| `mercado_fg` | `places/mercado/fg.png` | recorte | 2880×1920 (3:2) | provisional | **falta** |
| `mercado_akba_overlay` | `places/mercado/akba_overlay.jpg` | aditivo | 2880×1920 (3:2) | provisional | real |
| `plaza_bg_day/dusk/night` | `places/plaza/bg_*.jpg` | opaco | 2880×1920 (3:2) | provisional | real |
| `plaza_mid` | `places/plaza/mid.png` | recorte | 2880×1920 (3:2) | nada sobre fondo real | falta (opcional) |
| `plaza_fg` | `places/plaza/fg.png` | recorte | 2880×1920 (3:2) | provisional | **falta** |
| `plaza_akba_overlay` | `places/plaza/akba_overlay.jpg` | aditivo | 2880×1920 (3:2) | provisional | real (igual que las otras dos: es el mismo archivo, 613 508 bytes) |
| `portrait_sazil_idle`, `_hand_raised` | `portraits/…` | recorte | 1024×1024 (1:1) | silueta | real (falta la bolsa/sobre de cartera: ver `docs/art_todo.md`) |
| `portrait_akba_idle`, `_hand_raised` | `portraits/…` | recorte | 1024×1024 (1:1) | silueta | real |
| `hands_sazil_<idle, hold_letter, point, light, reach, wait, grip>` | `hands/…` | recorte | 1080×720 (3:2) | manos dibujadas | **faltan las 7** |
| `hands_akba_<idle, hold_letter, point, light, reach, wait, grip>` | `hands/…` | recorte | 1080×720 (3:2) | manos dibujadas | **faltan las 7** |
| `npc_<ruth, tun, lina, marcos, beto>_velo2/3` | `faces/…` | recorte | 1024×1024 (1:1) | cara dibujada «PROVISIONAL» | comunidad (no se genera) |

Ranuras que la interfaz necesita y **no existen** en el manifiesto:

| Qué | Dónde se ve | Hoy |
| --- | --- | --- |
| Iconos de los lugares en el mapa | Mapa | círculos lisos |
| Marcadores de punto interactivo (mirada de Sazil / fisura de Akba) | Escena | dos aros dibujados |
| Ilustración de cada final (`un_buen_dia`, `otra_vez`) | Medianoche | solo texto sobre azul |
| Esfera del reloj para la transición de bucle | Al empezar otro bucle | no hay transición |
| Icono de la app | Lanzador de Android | **el icono por defecto de Godot** (`icon.svg`) |
| Pantalla de arranque | Al abrir la app | la de Godot por defecto |

Discrepancias encontradas:

- **Manos en 3:2 y la Task pide 4:3.** El manifiesto y `hands_view.gd` usan 1080×720 (3:2); el encargo de arte de las manos es 4:3. Si llegan en 4:3, la ingesta las rechaza (tolerancia 2 %). Se pasan las 14 ranuras a 1080×810 (4:3).
- `assets/art_incoming/` no existe en este clon (está en `.gitignore`), así que no hay archivos sin ranura que comprobar aquí (p. ej. un `objects.png` que debería llamarse `plaza_fg.png`). La herramienta los lista en su informe: ver `--check` en `docs/art_pipeline.md`.
- `art_ingest.gd` no tiene modo de solo comprobar: siempre escribe.

## 2. Pantallas

| Pantalla | Captura | Problemas |
| --- | --- | --- |
| Cabecera (hora, bucle, «¿Qué hago?», Ajustes, Mapa, Cuaderno, Tiempo) | 02, 02_big | Todos los botones 120 px (40 dp). La hora no destaca: mismo peso que «Bucle 1». Botones gris oscuro sobre panel translúcido: se pierden sobre fondos oscuros (noche). Con texto Muy grande la fila de arriba se aprieta y el título de lugar ocupa 2 líneas. |
| Selector Sazil/Akba | 02, 05 | Al mantener pulsado cambia el retrato sin transición. Con texto grande, «Observatorio» se corta («Observat…»). Estado activo por color y grosor de borde (bien), pero el inactivo de Sazil se confunde con el activo de día. |
| Escena del lugar | 02, 03, 07, 24 | Las manos provisionales son pequeñas, blancas y finas (no se leen en el móvil). El primer plano provisional son manchas negras en las esquinas. La etiqueta de un punto descubierto («Relojes que se atrasan») es texto claro fino sobre el fondo: poco contraste. Los puntos interactivos son dos aros casi iguales (mirada y fisura solo se distinguen por color). No hay pista de que se puede arrastrar para mirar (ni flechas en los bordes). La acción 3.ª queda cortada sin indicio de que hay más (scroll). Chips de persona de 150×120. Cuando el protagonista está en un lugar sin escena (24) las manos flotan sobre negro. |
| Relevo Sazil ⇄ Akba | — | Barrido de color plano; sin borde, se lee como un destello y no como cambio de mirada. |
| Mapa | 06, 07 | Nodos lisos (beige o gris), etiquetas que pisan otros nodos («Observatorio»). «Aquí» solo se ve por el sol dentro del nodo; el otro protagonista es un punto diminuto. No se dice cuánto cuesta ir (30 min). Leyenda mínima. Botón Cerrar 120 px. |
| Vista previa desde el mapa | 07, 07_big | El aviso «aún no estás aquí…» va en la línea de título; con texto grande ocupa 3 líneas y empuja la escena. |
| Diálogo | 08 | Hoja de papel sin borde; botón de 120 px; «Nuevo en el Cuaderno» sin icono. Correcto en general. |
| Conversación | 09, 10, 09_big, task-04/04 | **La segunda fila de cartas queda bajo el pliegue** en cuanto hay 5 cartas o dos frases largas (captura de la Task 04) y siempre con texto grande. Muros y puertas en 3 líneas de texto («Muro · ?»), sin forma propia. Cartas sin icono de tipo. Las manos ocupan 120 px y apenas se ven. El final forzado solo cambia el texto. |
| Momento de quiebre | 11, 12, 13 | Elegir modo: correcto. Sosteniendo: la grieta y el anillo bien, manos minúsculas, el botón «Sostener» no dice si hay que mantener o tocar (solo el texto de ayuda). **La pausa solo cambia una frase**: el anillo sigue igual. |
| Cuaderno | 14–18, *_big | **Con texto Muy grande las pestañas no caben y todo el contenido se desborda por la izquierda** (texto cortado: «Qué dice…», «elojería…»). Pestañas de 120 px. Datos como líneas sueltas sin tarjetas; los estados vacíos son una frase gris. Sin sección de créditos (solo sale el crédito en Velo 3). |
| Ajustes | 19, 19_big | **Los interruptores son un punto de 12 px** (Movimiento reducido, Silenciar): no se ve si están puestos. Deslizadores con agarrador invisible. Estilos de pista hechos a mano en el script. |
| Herramientas | 20 | Correcto; botones de 120 px. |
| Consejos (primera vez) | 01 | Hoja genérica abajo, sin señalar lo que explica (el selector, el Cuaderno, Tiempo). |
| Medianoche (finales) | 21, 22 | Solo texto sobre azul, media pantalla vacía. Sin ilustración. |
| Transición de bucle | 23 | No existe: el bucle nuevo aparece de golpe. |
| Icono / arranque | — | Los de Godot por defecto. |

## 3. Sistema visual

- El tema vive incrustado en `scenes/main.tscn`; además hay estilos sueltos en `switch_button.gd` (placa del retrato), `map_view.gd` (nodos), `settings_view.gd` (deslizadores), `silhouette.tscn` (disco), `confianza_pips.gd`, `sustain_ring.gd`, `place_view.gd` y `hands_view.gd` (colores propios) y separaciones distintas en cada escena (6, 8, 12, 14, 16, 18, 20, 24, 28, 36 px).
- No hay contorno negro en ningún control: el arte (trazo negro grueso, colores planos saturados, violeta con neones rosa/verde/cian/amarillo) y la interfaz (paneles grises redondeados) parecen de juegos distintos.
- Contraste: el texto apagado de noche (`NightMuted`) sobre el panel translúcido de arriba depende del fondo; sobre el cielo de día baja. El resto del texto de cuerpo pasa 4,5:1.
- Estados solo por color: pestaña activa (marrón), chip elegido, modo elegido, mirada/fisura en la escena.
- Las capturas de `docs/screenshots/` se importaban como texturas (y entraban en el APK): faltaba `docs/.gdignore`. Faltaban también en git los `.uid` de los scripts de la Task 04.

## 4. Lista de trabajo

Los bloques 1-5 de la Task 06 cubren todo lo anterior; además, de esta auditoría:

1. Medida táctil mínima 144 px (48 dp a 360 dp de ancho) en todos los controles nuevos y existentes.
2. Pestañas del Cuaderno que nunca desbordan (se reparten el ancho y parten la palabra).
3. Manos 4:3 en el manifiesto y en `hands_view.gd`.
4. Interruptores y deslizadores grandes, con forma de encendido/apagado (no solo color).
5. Modo `--check` en la ingesta de arte.
6. Manos ocultas cuando el protagonista está en un lugar sin escena.
