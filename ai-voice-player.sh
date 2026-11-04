#!/usr/bin/env bash
# Pick a random local clip and play it through PulseAudio/PipeWire.

ai_voice_pick_audio_file() {
    local target="$1"

    if [ -f "$target" ]; then
        printf '%s\n' "$target"
        return 0
    fi

    if [ -d "$target" ]; then
        local wavs=()
        while IFS= read -r -d '' f; do wavs+=("$f"); done \
            < <(find "$target" -maxdepth 1 -type f -iname '*.wav' -print0 2>/dev/null)
        if [ "${#wavs[@]}" -gt 0 ]; then
            printf '%s\n' "${wavs[RANDOM % ${#wavs[@]}]}"
            return 0
        fi

        local mp3s=()
        while IFS= read -r -d '' f; do mp3s+=("$f"); done \
            < <(find "$target" -maxdepth 1 -type f -iname '*.mp3' -print0 2>/dev/null)
        if [ "${#mp3s[@]}" -gt 0 ]; then
            printf '%s\n' "${mp3s[RANDOM % ${#mp3s[@]}]}"
            return 0
        fi
    fi

    return 1
}

ai_voice_has_playable_target() {
    local target="$1"
    [ -e "$target" ] || return 1
    find "$target" -maxdepth 1 -type f \( -iname '*.wav' -o -iname '*.mp3' \) -print -quit 2>/dev/null | grep -q .
}

ai_voice_play() {
    local target="$1"
    local path
    path="$(ai_voice_pick_audio_file "$target")" || return 3

    local notification_sink="${AI_VOICE_SINK:-}"
    command -v paplay >/dev/null 2>&1 || return 2
    # WirePlumber may remember a music route for generic paplay streams.
    # Give cues their own identity so they follow the chosen/default sink.
    local pulse_props="application.name=ai-voice media.role=event"
    if [ -n "$notification_sink" ]; then
        PULSE_PROP="$pulse_props" paplay --device="$notification_sink" "$path" >/dev/null 2>&1
    else
        PULSE_PROP="$pulse_props" paplay "$path" >/dev/null 2>&1
    fi
}
