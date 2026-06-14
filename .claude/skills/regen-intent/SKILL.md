---
name: regen-intent
description: Regenera los .wav de uno o varios intents vía Narakeet sin tocar los demás. Úsalo cuando se cambien líneas en narakeet-lines.csv o se quiera reemplazar audio de un intent concreto. Args: lista de intents separados por espacio (ej. "complete error"). Sin args, lista los intents disponibles y pregunta.
disable-model-invocation: true
---

# /regen-intent

Regenera audio solo para los intents indicados. Reutiliza la lógica de skip-on-exists de `generate-narakeet.mjs`: borrando los .wav del intent objetivo, el generador rellena lo faltante sin pisar el resto.

## Args

`$ARGUMENTS` = uno o más nombres de intent separados por espacio (ej. `complete`, `error blocked`).

Si está vacío: lista los directorios de intents existentes y pregunta cuál(es). No avances sin elección explícita.

## Pasos

1. Verifica que `$env:NARAKEET_API_KEY` está seteado (el usuario lo tiene configurado; si falta, detente y dile).
2. Para cada intent en `$ARGUMENTS`:
   - Comprueba que existe la carpeta `<intent>/` en la raíz del repo.
   - Comprueba que el intent aparece como valor de la columna `intent` en `narakeet-lines.csv`. Si no, detente y pregunta.
   - **Confirma con el usuario antes de borrar** — la regeneración consume créditos de Narakeet y reemplaza audio en vivo. Muestra cuántos .wav se borrarán por intent.
   - Borra los `.wav` dentro de `<intent>/`.
3. Ejecuta: `node .\generate-narakeet.mjs` (sin `--overwrite`). El generador solo regenera lo que no existe — los otros intents se mantienen intactos.
4. Verifica que los .wav nuevos están en disco (`Get-ChildItem <intent>\*.wav`).
5. Reporta los archivos creados y sugiere probar con `/test-intent <intent>` si está disponible.

## No hacer

- No uses `--overwrite` directamente (regenera todo el CSV, gasta créditos innecesariamente).
- No modifiques `narakeet-lines.csv` desde este skill. Si el texto cambia, el usuario lo edita primero.
- No invoques el daemon ni reproduzcas audio aquí — eso es `/test-intent`.
