# ai-voice

Small local voice notification library for Claude, Codex and Copilot events.

## Current audio intents

- `notif`: user input is needed.
- `complete`: a task finished.
- `stop`: fallback completion sound.
- `thinking`: work started or analysis is in progress.
- `error`: something failed.
- `permission`: approval or access is needed.
- `warning`: something should be reviewed before continuing.
- `blocked`: progress depends on more information.
- `success`: a check, build, or action succeeded.
- `long_task`: a longer task is starting.
- `resume`: work is being resumed.
- `handoff`: work is ready for human review or ownership transfer.
- `wakeup`: a scheduled or automated run started cold.
- `commit`: git checkpoint or commit completed.
- `clarify`: a specific clarification is needed.

Each folder can contain numbered MP3 files such as `1.mp3`, `2.mp3`, and `3.mp3`. The player randomly selects one MP3 from the target folder.

## Generate new Narakeet clips

Add or edit phrases in `narakeet-lines.csv`, then set your Narakeet API key and run:

```powershell
$env:NARAKEET_API_KEY = "your-api-key"
node .\generate-narakeet.mjs
```

By default the script uses the `alejandra` voice and writes MP3 files into the intent folders. Existing files are skipped unless you pass `--overwrite`.

```powershell
node .\generate-narakeet.mjs --overwrite
```

## Event routing

### Claude Code (`claude-notify.ps1`)

Reads JSON from stdin. Maps Claude Code hook events automatically:

- `Notification` + "permission" message → `permission`
- `Notification` → `notif`
- `Stop` → `complete`
- `SubagentStop` → `handoff`
- `SessionStart` startup → `wakeup`
- `SessionStart` resume → `resume`
- `PostToolUse` git commit → `commit`

Configured in `~/.claude/settings.json` under `hooks`.

### Codex (`codex-notify.ps1`)

Accepts `-NotificationJson` parameter. Maps Codex event types:

- `agent-turn-user-prompt` → `notif`
- `agent-turn-complete` → `complete`
- `agent-turn-stop` → `stop`

Custom payloads can pass `intent` or `sound` to target any folder directly, for example `error`, `permission`, or `thinking`.

### VS Code Copilot (`copilot-notify.ps1`)

Accepts `-Intent` (direct) or `-NotificationJson` (structured). Maps VS Code events:

- `chat.submit` → `thinking`
- `chat.response` → `complete`
- `chat.stop` → `stop`
- `inline.accept` → `success`
- `inline.reject` → `stop`
- `task.start` → `long_task`
- `task.complete` → `complete`
- `task.error` → `error`
- `agent.handoff` → `handoff`
- `agent.blocked` → `blocked`
- `agent.permission` → `permission`

**Integration via Signal_AI extension** (`c:\dev\Signal_AI`):

The `CopilotNotificationService` inside Signal_AI hooks into VS Code task events automatically and exposes the `signalAi.notify` command for keybindings.

Trigger any sound from a VS Code keybinding:

```json
{ "command": "signalAi.notify", "args": { "intent": "thinking" } }
```

Or call the script directly from a terminal:

```powershell
.\copilot-notify.ps1 -Intent complete
.\copilot-notify.ps1 -NotificationJson '{"event":"task.error"}'
```
