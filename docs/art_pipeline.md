# Arte: cómo entra en el juego

El juego funciona sin arte: cada ranura que falta se dibuja con un provisional (formas planas con la etiqueta «PROVISIONAL · ranura») y avisa una sola vez en la consola. En cuanto aparece el archivo de una ranura, el juego lo usa.

## Carpetas

- `assets/art_incoming/`: aquí se deja lo que llega (PNG, JPG o WebP, tal cual sale del generador). Está en `.gitignore` y tiene un `.gdignore`: no se versiona ni entra en el APK.
- `assets/art/`: lo que usa el juego, ya preparado por la herramienta. Sí se versiona.
- `data/art_manifest.json`: la lista de ranuras, con su ruta, tamaño, tipo y qué hacer si falta.

## Nombres

Cada archivo se llama como su ranura: `<id>.png` (o `.jpg`, `.webp`). Por ejemplo `plaza_bg_night.jpg` o `portrait_akba_hand_raised.png`.

| Ranuras | Tamaño final | Tipo |
| --- | --- | --- |
| `<lugar>_bg_day`, `_bg_dusk`, `_bg_night` | 2880×1920 | opaco |
| `<lugar>_mid` (opcional si ya hay fondos de verdad) | 2880×1920 | recorte |
| `<lugar>_fg` | 2880×1920 | recorte |
| `<lugar>_akba_overlay` (sobre negro puro) | 2880×1920 | aditivo |
| `portrait_<sazil|akba>_idle`, `_hand_raised` | 1024×1024 | recorte |
| `hands_<sazil|akba>_<idle|hold_letter|point|light|reach|wait>` | 1080×720 | recorte |

Los lugares son `relojeria`, `mercado` y `plaza`.

- **Recorte**: fondo magenta plano (de #E010C8 a #FF00FF). La herramienta lo vuelve transparente rellenando desde el borde de la imagen, así que el rosa, la piel o las flores malva de dentro del dibujo no se tocan. También limpia el borde mezclado del trazo y el halo de luz (el brillo verde del colgante de Akba). Conviene que el trazo negro cierre bien el dibujo.
- **Aditivo**: sobre negro puro. Se suma a la escena (el negro no añade nada), sin recortar.
- **Proporción**: se acepta hasta un 2 % de diferencia con la del manifiesto (3:2 en los lugares, 1:1 en los retratos) y se estira al tamaño exacto (Lanczos). Si no encaja, el informe lo dice y la ranura no se toca.
- **Retratos**: el botón del selector enseña solo la cara. El recorte es `focus` en el manifiesto: [x, y, ancho, alto] en fracciones de la imagen.

## Cómo ejecutarla

```
godot --headless --path . --script res://scripts/dev/ingest_art.gd
godot --headless --path . --import
```

La primera orden prepara el arte e imprime qué ranuras están, cuáles faltan, qué no encaja, qué archivos no tienen ranura y cuántos MB ocupa (límite: 60 MB). Es idempotente: si la salida es más nueva que la entrada, no la rehace; añade `-- --force` para rehacer todo. La segunda orden importa el arte (o abre el editor).

La primera vez, la herramienta también escribe los ajustes de importación. Los fondos, la capa de Akba y los recortes grandes (`mid`, `fg`) llevan compresión VRAM sin mipmaps: en Android, un fondo es ETC2 de 4 bits por píxel (unos 2,8 MB). Retratos y manos van sin pérdida. Si la compresión deja marcas en un recorte, se cambia a «Lossless» en el editor. Después manda el editor.

## Al llegar arte nuevo

Las estaciones (`x`), `ground_y` y los puntos interactivos (`x`, `y`) de `data/scenes.json` están colocados a ojo sobre el arte actual. Hay que retocarlos mirando cada lugar.
