---
name: godot-android
description: Validar, exportar e instalar LifeSim (Godot 4.7) en Android. Usar para comprobar que el proyecto abre sin errores, generar el APK debug, instalarlo en el emulador o en el celular por adb, lanzarlo y leer los logs de Godot (logcat).
---

# Flujo Godot → Android para LifeSim

Rutas de este equipo (ver `%APPDATA%\Godot\editor_settings-4.7.tres`):

- Android SDK: `%LOCALAPPDATA%\Android\Sdk` (adb en `platform-tools\adb.exe`, emulador en `emulator\emulator.exe`)
- JDK: `C:\Program Files\Android\Android Studio\jbr`
- Plantillas de exportación: `%APPDATA%\Godot\export_templates\4.7.2.stable`
- AVD disponible: `Medium_Phone_API_37.0`
- Editor de Godot: `$env:GODOT`, definido en `.claude/settings.json` como `C:\Users\alecx\Downloads\Godot_v4.7.2-stable_win64_console.exe`. Usar siempre la versión `_console.exe`, porque el `.exe` normal no escribe nada en la terminal.

El preset de exportación se llama `Android` (`export_presets.cfg`), arm64-v8a, sin gradle build. No editar `export_presets.cfg` ni `android/` salvo que la tarea lo pida.

## 1. Validar el proyecto

```powershell
& $env:GODOT --headless --path . --quit
```

Leer la salida completa: cualquier `ERROR:` o `SCRIPT ERROR:` es un fallo. Para comprobar scripts sin abrir escena: `& $env:GODOT --headless --path . --check-only --script res://scripts/<archivo>.gd`.

## 2. Exportar APK debug

```powershell
New-Item -ItemType Directory -Force build | Out-Null
& $env:GODOT --headless --path . --export-debug "Android" build/lifesim-debug.apk
```

`build/` es salida generada; no se versiona.

## 3. Emulador / dispositivo

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb devices
# Si no hay dispositivos, arrancar el emulador en segundo plano:
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd Medium_Phone_API_37.0
& $adb wait-for-device
```

## 4. Instalar, lanzar y leer logs

El id del paquete sale de `package/unique_name` en `export_presets.cfg` (`com.example.$genname` → `com.example.lifesim`); confirmarlo con `& $adb shell pm list packages lifesim`.

```powershell
& $adb install -r build/lifesim-debug.apk
& $adb shell monkey -p com.example.lifesim -c android.intent.category.LAUNCHER 1
& $adb logcat -c
& $adb logcat -d -s godot:V GodotLib:V   # volcar logs de Godot
& $adb exec-out screencap -p > build/screen.png   # captura para revisar la UI
```

Revisar la captura (pantalla vertical, UI para el pulgar) y los logs antes de dar la tarea por terminada.
