#!/usr/bin/env bash
# Linux playback backend for ai-voice. Mirrors ai-voice-player.ps1's contract
# (pick a random clip from an intent folder, play it) using PulseAudio/ALSA
# tooling instead of System.Media.SoundPlayer / winmm.dll.

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

    if command -v paplay >/dev/null 2>&1; then
        paplay "$path" >/dev/null 2>&1 && return 0
    fi
    if command -v pw-play >/dev/null 2>&1; then
        pw-play "$path" >/dev/null 2>&1 && return 0
    fi
    if command -v ffplay >/dev/null 2>&1; then
        ffplay -nodisp -autoexit -loglevel quiet "$path" >/dev/null 2>&1 && return 0
    fi
    if command -v aplay >/dev/null 2>&1; then
        aplay -q "$path" >/dev/null 2>&1 && return 0
    fi

    return 2
}
