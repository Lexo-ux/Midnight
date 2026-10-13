# Vibración (háptica)

La vibración del juego la maneja el autoload `Haptics` (`scripts/haptics.gd`) con
los datos de `data/haptics.json`. Usa `Input.vibrate_handheld(duración_ms, intensidad)`:
en escritorio, sin pantalla (tests) o en un móvil sin motor de vibración no hace
nada y no falla.

## Paso manual (Alex): permiso VIBRATE en Android

El repositorio **no** toca `export_presets.cfg`. Para que el móvil vibre hay que
activar el permiso una vez en el editor:

1. Godot → **Proyecto → Exportar…**
2. Elegir el preajuste **Android**.
3. Pestaña **Permisos** (Permissions) → marcar **Vibrate**.
4. Guardar (se escribe en `export_presets.cfg`, en tu máquina).

Sin el permiso, el juego funciona igual: `vibrate_handheld` simplemente no vibra.

## Niveles (Ajustes → Vibración)

| Ajuste    | Clave en la partida | Multiplicador de intensidad |
|-----------|---------------------|-----------------------------|
| Apagada   | `off`               | 0 (no se llama a nada)      |
| Suave     | `low`               | 0.5                         |
| Normal    | `normal`            | 1.0 (por defecto)           |

El nivel se guarda en los ajustes de la partida (`settings.haptics`, guardado
versión 4). «Movimiento reducido» no apaga la vibración: tiene su propio ajuste.

## Patrones (`data/haptics.json`)

Cada patrón es una lista de pulsos `[espera_ms, duración_ms, intensidad 0-1]`;
la intensidad se multiplica por el nivel.

| Patrón          | Cuándo                                                    |
|-----------------|-----------------------------------------------------------|
| `switch`        | Al cambiar de Sazil a Akba o al revés (`main.gd`).        |
| `card`          | Al jugar una carta en una conversación.                  |
| `success`       | Al abrir una puerta en una conversación y al sostener un quiebre hasta el final. |
| `sustain_pulse` | Mientras se sostiene un quiebre: un pulso cada `sustain_interval_ms`, de `start` (900 ms) a `end` (260 ms) según se llena el anillo. |
| `let_go`        | Al soltar en un quiebre (un pulso largo).                 |

Para cambiar una sensación, edita `data/haptics.json`: no hace falta tocar código.
Un patrón nuevo solo suena si algún script llama a `Haptics.play("<nombre>")`.

## Comprobación

`scripts/dev/tests/test_audio_haptics.gd` comprueba que existen todos los
patrones que usa el juego, que «Apagada» no vibra, que «Suave» va a la mitad y
que los pulsos al sostener se aceleran. `Haptics.history` guarda las últimas
vibraciones pedidas para los tests.
