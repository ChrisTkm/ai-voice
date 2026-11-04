#!/usr/bin/env bash
# Play a named agent cue or a reminder cue from any local tool.
set -u
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ "$#" -ne 2 ] || [ "$1" != "agent" ] && [ "$1" != "reminder" ]; then
    printf 'Usage: %s {agent|reminder} INTENT\n' "$0" >&2
    exit 64
fi
[[ "$2" =~ ^[a-zA-Z0-9_-]+$ ]] || exit 64
if [ "$1" = reminder ]; then
    target="$root/reminders/$2"
else
    target="$root/$2"
fi
. "$root/ai-voice-player.sh"
ai_voice_play "$target"
