---
name: regen-intent
description: Regenerar WAV específicos de ai-voice con Narakeet después de revisar sus frases y el alcance del gasto.
---

# Regenerar audio

La reproducción normal no usa Narakeet. Para regenerar, lee `narakeet-lines.csv` o `reminders/narakeet-lines.csv`, identifica exactamente las filas solicitadas y crea un CSV temporal con encabezado `intent,file,text`. Comprueba que `NARAKEET_API_KEY` exista sin mostrar su valor. Explica qué WAV se reemplazarán y que la operación consume créditos antes de llamar a la API.

Usa `node generate-narakeet.mjs --lines <csv-temporal> --overwrite` para agentes. Para recordatorios agrega `--output-dir reminders`. Verifica los archivos creados y conserva los anteriores si la llamada falla.
