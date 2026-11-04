---
name: test-intent
description: Probar un aviso local de ai-voice en Arch Linux y revisar su salida de audio.
---

# Probar un aviso

En la raíz de ai-voice, ejecuta `./ai-voice.sh agent <intent>` o `./ai-voice.sh reminder <intent>` según lo que pida el usuario. Si no indica categoría o intent, enumera los disponibles y pide una elección. El comando reproduce un WAV por la salida predeterminada de PipeWire; `AI_VOICE_SINK` permite elegir otra salida.

Comprueba el código de salida. Si falla, revisa que exista un WAV en la carpeta, que `paplay` esté instalado y que PipeWire tenga un sink disponible. No afirmes que el usuario escuchó el audio solo porque el comando terminó correctamente.
