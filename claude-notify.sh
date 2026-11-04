#!/usr/bin/env bash
# Reads a Claude Code hook payload from stdin and plays its mapped intent.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
player_script="$root/ai-voice-player.sh"
log_file="$root/claude-notify.log"

log_msg() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$log_file" 2>/dev/null
}

if [ ! -f "$player_script" ]; then
    log_msg "missing player script: $player_script"
    exit 0
fi
# shellcheck source=/dev/null
source "$player_script"

stdin_text="$(cat)"

map_code=$(cat <<'PY'
import json, re, sys

data = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    payload = json.loads(data) if data.strip() else {}
except Exception:
    payload = {}

event = str(payload.get("hook_event_name", ""))
intent = ""

if event == "Notification":
    msg = str(payload.get("message", ""))
    intent = "permission" if re.search(r"(?i)permission", msg) else "notif"
elif event == "Stop":
    intent = "complete"
elif event == "SubagentStop":
    intent = "handoff"
elif event == "SessionStart":
    source = str(payload.get("source", ""))
    intent = {"startup": "wakeup", "resume": "resume"}.get(source, "")
elif event == "PostToolUse":
    tool = str(payload.get("tool_name", ""))
    if tool == "Bash":
        cmd = str((payload.get("tool_input") or {}).get("command", ""))
        if re.search(r"git\s+commit", cmd):
            intent = "commit"

print(f"{event}\t{intent}")
PY
)

mapping="$(python3 -c "$map_code" "$stdin_text" 2>>"$log_file")"
event="${mapping%%$'\t'*}"
intent="${mapping#*$'\t'}"

if [ -z "$intent" ]; then
    exit 0
fi

sound_target="$root/$intent"

if ! ai_voice_has_playable_target "$sound_target"; then
    log_msg "fallback intent=$intent target=$sound_target"
    sound_target="$root/complete"
fi

if ! ai_voice_has_playable_target "$sound_target"; then
    log_msg "no playable target intent=$intent"
    exit 0
fi

ai_voice_play "$sound_target"
play_exit=$?
log_msg "played intent=$intent event=$event target=$sound_target exit=$play_exit"
exit 0
