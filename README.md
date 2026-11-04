# ai-voice

`ai-voice` reproduce avisos de voz cortos a partir de eventos de asistentes y otras herramientas. Sirve para seguir varias sesiones sin tener que mirar cada una: un sonido indica que terminó un turno, llegó una pregunta o se necesita permiso.

Los avisos son WAV locales. La reproducción no requiere conexión, claves de API ni un servicio residente. Narakeet se usa únicamente para crear nuevos clips.

## Probarlo

En Linux, necesitas Bash, `paplay` y una salida PulseAudio o PipeWire disponible:

```bash
./ai-voice.sh agent complete
./ai-voice.sh agent permission
./ai-voice.sh reminder iva
```

`agent` reproduce una variante aleatoria de la carpeta indicada en la raíz. `reminder` busca en `reminders/`. Los recordatorios dependen de un calendario o programador externo: este proyecto solo reproduce el aviso. Por defecto usa la salida de audio del sistema; `AI_VOICE_SINK` permite elegir otra salida por nombre.

## Conectar herramientas

Una herramienta puede llamar a `ai-voice.sh` con un intent. Los adaptadores incluidos traducen los eventos propios de Codex y Claude Code:

```toml
# ~/.codex/config.toml
notify = ["/ruta/absoluta/ai-voice/codex-notify.sh"]
```

En Claude Code, configura los hooks `Notification` y `Stop` para ejecutar `/ruta/absoluta/ai-voice/claude-notify.sh`. El adaptador recibe el JSON por stdin. También entiende `SubagentStop`, `SessionStart` y algunos eventos `PostToolUse`. Conserva los hooks existentes al editar la configuración.

Un evento `complete` significa que terminó el turno del asistente; no verifica si la tarea entera tuvo éxito. Para Neovim, otras TUI o scripts, llama al comando directamente cuando ocurra el evento que te interesa.

## Biblioteca de voz

Los 112 WAV de agentes están organizados en 14 intents; hay 21 WAV de recordatorios. Los textos fuente están en `narakeet-lines.csv` y `reminders/narakeet-lines.csv`. `regen-pending.csv` registra dos frases cuyo texto cambió pero cuyo WAV aún no se regeneró.

El generador necesita Node.js. Omite los archivos existentes y **solo pide `NARAKEET_API_KEY` si hay algo que generar**:

```bash
node generate-narakeet.mjs
node generate-narakeet.mjs --lines reminders/narakeet-lines.csv --output-dir reminders
```

Para reemplazar clips, prepara un CSV con solo las filas deseadas y usa `--lines archivo.csv --overwrite`. Regenerar consume créditos de Narakeet; revisa primero el alcance. La clave se proporciona mediante una variable de entorno del shell, no dentro del repo.

## Verificación

```bash
bash -n ai-voice.sh ai-voice-player.sh codex-notify.sh claude-notify.sh
node --check generate-narakeet.mjs
./ai-voice.sh agent complete
```

Los logs locales de los adaptadores están ignorados por Git. Si un aviso no suena, comprueba el dispositivo predeterminado y prueba primero el comando directo.
