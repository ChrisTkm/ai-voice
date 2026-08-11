#!/usr/bin/env bash
# Codex notification adapter for Linux. Codex passes one JSON argument when a
# supported event is emitted (currently agent-turn-complete).

set -u

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
player_script="$root/ai-voice-player.sh"
log_file="$root/codex-notify.log"

write_log() {
    local message="$1"
    printf '[%(%Y-%m-%d %H:%M:%S)T] %s\n' -1 "$message" >>"$log_file" 2>/dev/null || true
}

if [ "${1:-}" = "--play" ]; then
    target="${2:-}"
    event_type="${3:-}"
    intent="${4:-}"
    # shellcheck source=ai-voice-player.sh
    . "$player_script" || exit 0
    ai_voice_play "$target"
    play_exit=$?
    write_log "played intent=$intent event=$event_type target=$target exit=$play_exit"
    exit 0
fi

[ -f "$player_script" ] || {
    write_log "missing player script: $player_script"
    exit 0
}

# shellcheck source=ai-voice-player.sh
. "$player_script" || exit 0

notification_json="${1:-}"
if [ -z "$notification_json" ] && [ ! -t 0 ]; then
    notification_json="$(cat)"
fi

event_type=""
intent=""
if [ -n "$notification_json" ] && command -v python3 >/dev/null 2>&1; then
    parsed="$({ python3 -c '
import json, sys
try:
    payload = json.loads(sys.argv[1])
except (json.JSONDecodeError, IndexError, TypeError):
    raise SystemExit(1)
print(str(payload.get("type", "")))
print(str(payload.get("intent") or payload.get("sound") or ""))
' "$notification_json"; } 2>/dev/null)" || parsed=""
    if [ -n "$parsed" ]; then
        event_type="${parsed%%$'\n'*}"
        if [[ "$parsed" == *$'\n'* ]]; then
            intent="${parsed#*$'\n'}"
        fi
    else
        write_log "invalid json"
    fi
fi

if [ -z "$intent" ]; then
    case "$event_type" in
        agent-turn-complete) intent="complete" ;;
        agent-turn-stop) intent="stop" ;;
        agent-turn-user-prompt) intent="notif" ;;
        *) intent="complete" ;;
    esac
fi

# Only simple intent folder names are accepted. This prevents a custom payload
# from selecting files outside the repository.
if [[ ! "$intent" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    write_log "invalid intent=$intent event=$event_type"
    intent="complete"
fi

sound_target="$root/$intent"
if ! ai_voice_has_playable_target "$sound_target" 2>/dev/null; then
    write_log "fallback intent=$intent event=$event_type target=$sound_target"
    intent="complete"
    sound_target="$root/complete"
fi

if ! ai_voice_has_playable_target "$sound_target" 2>/dev/null; then
    write_log "no playable target intent=$intent event=$event_type"
    exit 0
fi

# Detach playback so Codex can finish the turn without waiting for the clip.
nohup "$0" --play "$sound_target" "$event_type" "$intent" >/dev/null 2>&1 &
write_log "queued intent=$intent event=$event_type target=$sound_target"
exit 0
