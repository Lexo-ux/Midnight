# Arte de verdad que falta

Lo que hoy se ve con arte **provisional** (generado por
`scripts/dev/make_placeholder_art.gd` en `assets/art_provisional/`, marcado
`"provisional": true` en `data/art_manifest.json`). Cada archivo de verdad se
deja en `assets/art_incoming/<ranura>.png` (o `.jpg`/`.webp`) y se prepara con
`scripts/dev/ingest_art.gd` (ver `docs/art_pipeline.md`): en cuanto existe en
`assets/art/`, el juego lo usa en lugar del provisional, sin tocar código.

Antes de ingerir, conviene comprobar: `godot --headless --path . --script res://scripts/dev/ingest_art.gd -- --check`
(no escribe nada; dice qué entraría, qué proporción no encaja y a qué ranura se
parece cada archivo mal nombrado, p. ej. `objects.png → ¿plaza_fg?`).

Recorte = fondo magenta plano (#FF00FF), trazo negro que cierre el dibujo.
Opaco = imagen entera. Proporción: se acepta un 2 % de diferencia.

## 1. Manos en primera persona (14) — prioridad alta

Se ven siempre, abajo y en el centro de la escena. Entran por el borde de abajo,
cinco dedos, vistas por el dorso. **4:3, 1080×810, recorte.**

| Archivo | Qué |
| --- | --- |
| `hands_sazil_idle.png` | Reposo, las dos abajo. Manga de chaqueta ocre/terracota; guante sin dedos en la izquierda; la correa de la bolsa de correo cruzando abajo a la izquierda. |
| `hands_sazil_hold_letter.png` | Sostiene un sobre con las dos manos (lee, retiene, entrega o desvía cartas). |
| `hands_sazil_point.png` | Señala con la derecha (observar, seguir). |
| `hands_sazil_light.png` | Alza un candil pequeño de latón (no se usa con Sazil hoy, pero la ranura existe). |
| `hands_sazil_reach.png` | Las dos manos abiertas hacia delante (interactuar, jugar una carta). |
| `hands_sazil_wait.png` | Manos juntas, abajo, quietas (esperar). |
| `hands_sazil_grip.png` | Puños cerrados agarrando algo (sostener en un momento de quiebre). |
| `hands_akba_idle.png` | Reposo. Manga índigo oscuro del abrigo; en la izquierda, el farol de latón con la luz del Umbral (verde ácido con un filo carmesí: la gema del colgante). |
| `hands_akba_hold_letter.png` | Sostiene una carta doblada. |
| `hands_akba_point.png` | Señala con la derecha; el farol, bajo, en la izquierda. |
| `hands_akba_light.png` | Alza el farol (observar: con su luz ve el Umbral). Brillo verde/carmesí fuerte. |
| `hands_akba_reach.png` | Las dos manos abiertas hacia delante. |
| `hands_akba_wait.png` | Espera con el farol bajo en la izquierda. |
| `hands_akba_grip.png` | Puños agarrando un hilo de luz del Umbral. |

Ojo: Marcos es «el hombre del farol» (su farol no alumbra: busca). El de Akba
debe leerse distinto: latón con la luz verde y carmesí del colgante.

## 2. Capas de los lugares (6)

**3:2, 2880×1920, recorte.** El primer plano (`fg`) se mueve más rápido que la
escena (paralaje 1,3) y se oscurece un 30 %; la capa media (`mid`) va con la
gente. Nada por encima de los pies de la gente (`ground_y`: Relojería 1560,
Mercado 1600, Plaza 1620) salvo en los bordes, y nada sobre los puntos
interactivos ni las estaciones (`data/scenes.json`). Sin letras.

| Archivo | Qué |
| --- | --- |
| `relojeria_fg.png` | Marco bajo: verja de hierro, un engranaje de latón, un barril. |
| `mercado_fg.png` | Cajas de naranjas, cesta de pan, sacos; banderines en la esquina. |
| `plaza_fg.png` | Maceta con flores, farola, banco; farolillos de la Unión. |
| `relojeria_mid.png` | Opcional. Farola, caballete con esfera de reloj, bolardos. |
| `mercado_mid.png` | Opcional. Barril, cajas apiladas, farola, sacos. |
| `plaza_mid.png` | Opcional. Banco, farola, macetero. |

Además: las tres `akba_overlay.jpg` son hoy **el mismo archivo**. Cada lugar
debería tener sus grietas (sobre negro puro, 2880×1920, aditivo), con las
fisuras donde están los puntos de Akba (`data/scenes.json`).

## 3. Mapa, puntos interactivos y reloj

| Archivo | Tamaño | Qué |
| --- | --- | --- |
| `map_relojeria.png` | 512×512, 1:1, recorte | Icono del lugar en el mapa: la relojería con su gran esfera. |
| `map_mercado.png` | 512×512, 1:1, recorte | Un puesto con toldo de rayas y naranjas. |
| `map_plaza.png` | 512×512, 1:1, recorte | La torre del reloj torcida con banderines. |
| `map_unexplored.png` | 512×512, 1:1, recorte | Lugar sin explorar: casa en niebla, contorno discontinuo. |
| `hotspot_look.png` | 256×256, 1:1, recorte | Centro del marcador de un punto de Sazil (un ojo). |
| `hotspot_fissure.png` | 256×256, 1:1, recorte | Centro del marcador de una fisura de Akba (grieta en rombo). |
| `loop_reset_clock.png` | 1024×1024, 1:1, recorte | Esfera para la transición de bucle, **sin agujas** (las mueve el código hacia atrás). |

## 4. Finales, icono y arranque

| Archivo | Tamaño | Qué |
| --- | --- | --- |
| `ending_un_buen_dia.jpg` | 1080×720, 3:2, opaco | La fiesta de la Unión: farolillos, fuegos, Lina, Tun y Beto enteros. |
| `ending_otra_vez.jpg` | 1080×720, 3:2, opaco | La ciudad doblándose como un papel bajo el reloj que vuelve a las dos. |
| `app_icon.png` | 1024×1024, 1:1, opaco | Icono de la app. Lo importante dentro del círculo central (66 %): Android lo recorta. |
| `app_splash.png` | 1080×1920, 9:16, opaco | Pantalla de arranque, sin letras. |

**Paso a mano** después de ingerir `app_icon` y `app_splash`: en *Proyecto >
Configuración del proyecto* cambiar `application/config/icon` y
`application/boot_splash/image` de `res://assets/art_provisional/app/…` a
`res://assets/art/app/…` (el icono y el arranque son ajustes del proyecto, no se
resuelven en el juego).

## 5. Retoques del arte que ya hay

- **Retrato de Sazil** (`portrait_sazil_idle.png`, `portrait_sazil_hand_raised.png`, 1024×1024, recorte): falta su rasgo fijo, la **bolsa de correo / un sobre** (en `npcs.json`: «trenza lateral y bolsa de correo»). Hoy solo se ve la trenza.

## 6. No es del estudio

Las caras de Velo 2-3 (`npc_<persona>_velo2/3`) las hace la comunidad; mientras
tanto se dibujan en código con la etiqueta «PROVISIONAL». No se generan.

## Cuando llegue el arte

1. Copiar los archivos a `assets/art_incoming/` con el nombre de su ranura.
2. `ingest_art.gd -- --check`; arreglar nombres y proporciones que avise.
3. `ingest_art.gd` y abrir el editor (o `godot --headless --path . --import`).
4. Cuando una ranura tenga arte de verdad, su provisional ya no se usa: se puede
   borrar de `assets/art_provisional/` y quitar su `"provisional": true`.
5. Recolocar estaciones y puntos de `data/scenes.json` mirando el arte nuevo.
