# ai-voice integration manual

This is the handoff document for wiring `ai-voice` into other assistants.

`Signal`, the Codex pet, is visual and belongs to Codex. `ai-voice` is the portable audio layer. Copilot, Claude, Codex, or another tool should call the scripts in this repo when something happens.

## Quick test

From PowerShell in this folder:

```powershell
cd C:\dev\ai-voice
.\copilot-notify.ps1 -Intent thinking
.\copilot-notify.ps1 -Intent complete
.\claude-notify.ps1
.\codex-notify.ps1 -NotificationJson '{"type":"agent-turn-complete"}'
```

For lower latency, keep the resident daemon running in one terminal:

```powershell
cd C:\dev\ai-voice
.\ai-voice-daemon.ps1
```

Then call the normal `*-notify.ps1` scripts from other tools. They queue into the daemon when it is alive, and fall back to direct playback when it is not.

## Intents

Use these intent names as the stable API:

```text
notif, complete, stop, thinking, error, permission, warning,
blocked, success, long_task, resume, handoff, wakeup, commit, clarify
```

Any tool can trigger one directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\dev\ai-voice\copilot-notify.ps1" -Intent permission
```

## Claude Code terminal

Claude Code has native hooks. This is the cleanest integration.

Add hooks to one of these files:

- User-wide: `%USERPROFILE%\.claude\settings.json`
- Project-only: `C:\dev\ai-voice\.claude\settings.local.json`

Example:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\dev\\ai-voice\\claude-notify.ps1\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\dev\\ai-voice\\claude-notify.ps1\""
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\dev\\ai-voice\\claude-notify.ps1\""
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\dev\\ai-voice\\claude-notify.ps1\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\dev\\ai-voice\\claude-notify.ps1\""
          }
        ]
      }
    ]
  }
}
```

`claude-notify.ps1` reads the JSON hook payload from stdin and maps events:

- `Notification` -> `notif`
- `Notification` with a permission message -> `permission`
- `Stop` -> `complete`
- `SubagentStop` -> `handoff`
- `SessionStart` startup -> `wakeup`
- `SessionStart` resume -> `resume`
- `PostToolUse` Bash command containing `git commit` -> `commit`

Ask Claude to do this:

```text
Configure Claude Code hooks for ai-voice. Use C:\dev\ai-voice\INTEGRATIONS.md as the source of truth. Edit my Claude settings file safely, preserve existing hooks, and add commands that call C:\dev\ai-voice\claude-notify.ps1.
```

Claude can usually edit its project settings itself if you allow the file write. For user-wide settings, approve the edit only after checking the diff.

## GitHub Copilot in VS Code

Copilot Chat in VS Code does not expose the same simple universal hook file that Claude Code does. So there are three practical levels:

1. Manual trigger: run `.\copilot-notify.ps1 -Intent <intent>` from a VS Code terminal.
2. VS Code tasks/keybindings: create commands that call `copilot-notify.ps1` for common events.
3. Small VS Code extension: use VS Code extension APIs to add richer Copilot/chat-aware behavior.

Recommended starter `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "ai-voice: thinking",
      "type": "shell",
      "command": "powershell",
      "args": [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "C:\\dev\\ai-voice\\copilot-notify.ps1",
        "-Intent",
        "thinking"
      ],
      "problemMatcher": []
    },
    {
      "label": "ai-voice: complete",
      "type": "shell",
      "command": "powershell",
      "args": [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "C:\\dev\\ai-voice\\copilot-notify.ps1",
        "-Intent",
        "complete"
      ],
      "problemMatcher": []
    },
    {
      "label": "ai-voice: permission",
      "type": "shell",
      "command": "powershell",
      "args": [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "C:\\dev\\ai-voice\\copilot-notify.ps1",
        "-Intent",
        "permission"
      ],
      "problemMatcher": []
    }
  ]
}
```

Ask Copilot to do this:

```text
Configure VS Code tasks for ai-voice. Use C:\dev\ai-voice\INTEGRATIONS.md as the source of truth. Create or update .vscode/tasks.json without deleting existing tasks. Add tasks for thinking, complete, permission, error, blocked, and success that call C:\dev\ai-voice\copilot-notify.ps1.
```

For real automatic Copilot events, ask Copilot to scaffold a VS Code extension that calls:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\dev\ai-voice\copilot-notify.ps1" -NotificationJson '{"event":"task.complete"}'
```

Supported `copilot-notify.ps1` event mappings:

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

## What assistants should not do

- Do not move audio-domain mapping logic into a Copilot or Claude config.
- Do not modify the generated pet files to make audio work.
- Do not hardcode individual WAV file paths; call intent folders through the notify scripts.
- Do not delete existing hooks, tasks, or user settings while adding `ai-voice`.

## Troubleshooting

Check logs in this folder:

```text
ai-voice-daemon.log
claude-notify.log
codex-notify.log
copilot-notify.log
```

If nothing plays:

1. Test direct playback with `.\copilot-notify.ps1 -Intent complete`.
2. Check that the intent folder contains `.wav` or `.mp3` files.
3. Start `.\ai-voice-daemon.ps1` and try again.
4. Confirm PowerShell execution policy is bypassed in external commands.
5. Check the relevant log file.
