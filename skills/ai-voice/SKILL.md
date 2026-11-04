---
name: ai-voice
description: Usar, configurar o mantener los avisos de voz locales de ai-voice para agentes, recordatorios y herramientas de terminal.
---

# ai-voice

Este repo reproduce WAV locales por intent. Úsalo cuando una herramienta deba avisar que terminó un turno, necesita una respuesta o requiere permiso. En reproducción no hace llamadas a Narakeet ni necesita un daemon.

## Reproducir e integrar

- Ejecuta `./ai-voice.sh agent <intent>` para avisos de agentes o `./ai-voice.sh reminder <intent>` para recordatorios. Comprueba que la carpeta tenga al menos un WAV antes de agregar un intent nuevo.
- En Linux, `paplay` usa la salida predeterminada. `AI_VOICE_SINK=<nombre>` selecciona otra salida si el usuario la pide. No presupongas un dispositivo específico.
- Para Codex, usa el hook `notify = ["/ruta/absoluta/codex-notify.sh"]` en `~/.codex/config.toml`. Para Claude Code, configura los hooks necesarios para llamar a `claude-notify.sh` y conserva cualquier hook existente.
- `complete` describe el final de un turno; no implica que toda la tarea esté resuelta. Una fuente externa decide cuándo activar un recordatorio.

## Mantener los audios

- `narakeet-lines.csv` y `reminders/narakeet-lines.csv` son los textos fuente. Los WAV van en `<intent>/N.wav` y `reminders/<intent>/N.wav` respectivamente.
- `node generate-narakeet.mjs` comprueba el catálogo de agentes y omite los WAV existentes. Para recordatorios, usa `--lines reminders/narakeet-lines.csv --output-dir reminders`.
- Si un WAV debe reemplazarse, limita el CSV a las filas deseadas y agrega `--overwrite`. Antes de llamar a Narakeet, revisa los destinos, conserva los originales y confirma que `NARAKEET_API_KEY` esté disponible sin mostrar su valor. Generar audio consume créditos.
- Comprueba scripts con `bash -n` y `node --check`. Un comando de reproducción con código 0 demuestra que el sistema aceptó el audio, no que el usuario lo haya escuchado.
