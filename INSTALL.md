# Installing ai-voice

`ai-voice` is installed as a local clone. There is no marketplace package yet.

## Requirements

- Windows with PowerShell
- A working audio output device
- Node.js only when regenerating Narakeet clips

## Clone

Use the stable path when possible, because integration examples and agent skills refer to it:

```powershell
git clone https://github.com/ChrisTkm/ai-voice.git C:\dev\ai-voice
cd C:\dev\ai-voice
```

## Verify

Run the smoke test:

```powershell
.\tests\smoke.ps1
```

Then test audible playback:

```powershell
.\copilot-notify.ps1 -Intent complete
```

For normal daily use, keep the daemon running in another terminal:

```powershell
.\ai-voice-daemon.ps1
```

The daemon is the lightweight path. Notify scripts can return quickly by placing a tiny request in the local queue instead of making the calling assistant wait for the WAV to finish.

## Wire an assistant

External tools should call the notify scripts, not individual `.wav` files.

Generic command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\dev\ai-voice\copilot-notify.ps1" -Intent complete
```

For platform-specific examples, use [`INTEGRATIONS.md`](INTEGRATIONS.md).

The integration should stay boring on purpose: one command per event, no generated speech during the event, no pet process, and no duplicated routing logic in the host.

For security notes, see [`SECURITY.md`](SECURITY.md).

## Do users need a skill?

No. The runtime is just this repository plus a host that calls one of the notify scripts.

Skills are optional helper instructions for AI assistants. They are useful when you want Claude, Codex, Copilot, or another agent to configure hooks safely, regenerate clips, or run tests, but they are not required for playback.

## Adding more responses

Adding more phrases to an existing intent does not change the system architecture. Add rows to `narakeet-lines.csv`, mirror the phrases in `voice-library.json`, then run:

```powershell
$env:NARAKEET_API_KEY = "<your-real-narakeet-api-key>"
node .\generate-narakeet.mjs
```

The generator skips existing files by default, so only missing clips are created. Creating new audio consumes Narakeet minutes.
