---
name: test-intent
description: Reproduce un intent para verificar audio y enrutamiento. Úsalo después de regenerar un .wav, al añadir un intent nuevo, o para confirmar que el daemon responde. Args: nombre del intent (ej. "complete", "error").
---

# /test-intent

Reproduce el intent indicado a través del flujo normal de notify (no llama al .wav directamente — eso esquiva el daemon y enmascara bugs de enrutamiento).

## Args

`$ARGUMENTS` = un nombre de intent. Si está vacío, lista los intents disponibles (carpetas en la raíz con `.wav` dentro) y pregunta cuál.

## Pasos

1. Valida que existe la carpeta `<intent>/` y contiene al menos un `.wav`. Si no, detente.
2. Ejecuta: `.\copilot-notify.ps1 -Intent <intent>`
   - El daemon (si está corriendo) reproduce sin warm-up perceptible.
   - Si el daemon no responde, el script cae al modo directo automáticamente.
3. Reporta qué archivo se eligió (mira la última línea de `copilot-notify.log` si hace falta).

## Notas

- No uses `ai-voice-player.ps1` directamente para tests — salta el routing y el daemon, que son justo lo que queremos verificar.
- Si pruebas varios intents seguidos, espera ~1s entre llamadas para que el daemon procese la cola.
- Para confirmar el warm-up del dispositivo, el primer intent tras varios minutos de silencio puede sonar levemente recortado — es esperado y mitigado por el ciclo de warm-up de 20s del daemon.
