# ai-voice

> Local voice cues for agent workflows.
>
> Short, intentional, human-friendly audio feedback for Claude, Codex, Copilot, or any other tool that can emit an event.

`ai-voice` is a small local audio layer that turns machine events into clear audible signals. It is not a general TTS reader and it is not tied to one editor, one extension, or one AI product.

## Why this exists

When an agent is working in the background, visual feedback is easy to miss. `ai-voice` solves that with short clips mapped to meaningful intents like "thinking", "complete", or "permission".

Design goals:

- local-first and low-latency
- passive by default: the tool should speak, then get out of the way
- pleasant voice identity over generic system TTS
- short clips instead of long spoken output
- one small command from scripts, hooks, or editor automation
- no hard dependency on `Signal_AI` or any single host application

## Release direction

For `v0.1.0`, "lightweight" means lightweight in system flow, not tiny in audio size.

The happy path is:

1. a host emits an event
2. one notify script maps it to an intent
3. the resident daemon plays a short local WAV

That keeps `ai-voice` passive: no UI, no pet runtime, no dynamic TTS during normal use, no marketplace ceremony, and no host-specific audio rules outside this repo.

## Core model

The unit of playback is an `intent`.

Each intent maps to a folder with one or more numbered WAV files such as `1.wav`, `2.wav`, and `3.wav`. The player randomly selects one file from the target folder. MP3 files are still accepted as a fallback while migrating older audio sets.

Current intents:

- `notif`: user input is needed
- `complete`: a task finished
- `stop`: fallback completion sound
- `thinking`: work started or analysis is in progress
- `error`: something failed
- `permission`: approval or access is needed
- `warning`: something should be reviewed before continuing
- `blocked`: progress depends on more information
- `success`: a check, build, or action succeeded
- `long_task`: a longer task is starting
- `resume`: work is being resumed
- `handoff`: work is ready for human review or ownership transfer
- `wakeup`: a scheduled or automated run started cold
- `commit`: git checkpoint or commit completed
- `clarify`: a specific clarification is needed

## Repository layout

```text
ai-voice/
|- claude-notify.ps1
|- codex-notify.ps1
|- copilot-notify.ps1
|- generate-narakeet.mjs
|- ai-voice-player.ps1
|- narakeet-lines.csv
|- voice-library.json
|- thinking/
|- complete/
|- permission/
|- ...
```

## Quick usage

Run a sound directly from PowerShell:

```powershell
.\copilot-notify.ps1 -Intent thinking
.\copilot-notify.ps1 -Intent complete
.\copilot-notify.ps1 -NotificationJson '{"event":"task.error"}'
```

The same idea applies to any host application: emit a small event or pass an explicit `intent`, and `ai-voice` handles playback.

For setup instructions you can hand to Claude Code, GitHub Copilot in VS Code, or another assistant, see [`INTEGRATIONS.md`](INTEGRATIONS.md).

For first-time installation, see [`INSTALL.md`](INSTALL.md).

Useful release docs:

- [`TESTING.md`](TESTING.md): smoke tests and audible QA
- [`SECURITY.md`](SECURITY.md): local runtime, API key, and integration boundaries
- [`RELEASE.md`](RELEASE.md): `v0.1.0` release intent and merge checklist

For the lowest latency, keep the resident player running:

```powershell
.\ai-voice-daemon.ps1
```

In another terminal, call the normal notification scripts. They enqueue playback to the resident player when it is available, which avoids making the host wait for the clip to finish. If the daemon is not running, the scripts fall back to direct playback so the tool still works.

## Event routing

### Claude Code (`claude-notify.ps1`)

Reads JSON from stdin. Maps Claude Code hook events automatically:

- `Notification` + "permission" message -> `permission`
- `Notification` -> `notif`
- `Stop` -> `complete`
- `SubagentStop` -> `handoff`
- `SessionStart` startup -> `wakeup`
- `SessionStart` resume -> `resume`
- `PostToolUse` git commit -> `commit`

Configured in `~/.claude/settings.json` under `hooks`.

### Codex (`codex-notify.ps1`)

Accepts `-NotificationJson`. Maps Codex event types:

- `agent-turn-user-prompt` -> `notif`
- `agent-turn-complete` -> `complete`
- `agent-turn-stop` -> `stop`

Custom payloads can pass `intent` or `sound` to target any folder directly.

### VS Code Copilot (`copilot-notify.ps1`)

Accepts `-Intent` or `-NotificationJson`. Maps VS Code events:

- `chat.submit` -> `thinking`
- `chat.response` -> `complete`
- `chat.stop` -> `stop`
- `inline.accept` -> `success`
- `inline.reject` -> `stop`
- `task.start` -> `long_task`
- `task.complete` -> `complete`
- `task.error` -> `error`
- `agent.handoff` -> `handoff`
- `agent.blocked` -> `blocked`
- `agent.permission` -> `permission`

## Audio generation

This project currently favors curated short phrases over long dynamic TTS. The main reason is quality: the selected Narakeet voice works well for short notifications, while long free-form TTS is slower and less pleasant for repeated daily use.

Add or edit phrases in `narakeet-lines.csv`, then set your Narakeet API key and run:

```powershell
$env:NARAKEET_API_KEY = "<your-real-narakeet-api-key>"
node .\generate-narakeet.mjs
```

By default the script uses the `alejandra` voice and writes WAV files into the intent folders. WAV generation uses Narakeet's long-content polling API, so each clip can take a few seconds to finish. Existing files are skipped unless you pass `--overwrite`.

```powershell
node .\generate-narakeet.mjs --overwrite
```

If the audio device clips the first syllable after being idle, the player warms up the device with a short silent WAV before playing the selected clip.

## Integration boundary

`ai-voice` should stay decoupled from editor-specific or AI-specific products.

Valid relationship:

- an external tool invokes `ai-voice`

Invalid relationship:

- `ai-voice` depending on the internal logic of another project
- another project embedding audio-domain rules that belong here

In practice, `Signal_AI`, Claude, Codex, Copilot, or any future tool can call these scripts, but `ai-voice` remains its own small audio backend.

## License

Copyright (c) 2026 Albornoz Studio. All rights reserved.

This repository and its contents are a product of Albornoz Studio. See `LICENSE` for details.
