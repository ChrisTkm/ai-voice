# Testing ai-voice

Use this checklist before merging a release branch into `main`.

## Automated smoke test

```powershell
.\tests\smoke.ps1
```

This checks:

- required scripts exist
- canonical intents resolve to playable audio or a fallback
- `narakeet-lines.csv` and `voice-library.json` stay in sync

## Audible smoke test

```powershell
.\copilot-notify.ps1 -Intent complete
```

You should hear one short local clip and the command should exit with code `0`.

## Low-latency path

Start the daemon:

```powershell
.\ai-voice-daemon.ps1
```

In another terminal, trigger a few common intents:

```powershell
.\copilot-notify.ps1 -Intent thinking
.\copilot-notify.ps1 -Intent complete
.\copilot-notify.ps1 -Intent permission
.\copilot-notify.ps1 -Intent error
.\copilot-notify.ps1 -Intent blocked
```

The notify commands should return quickly because they enqueue a tiny request instead of waiting for the WAV to finish.

## Release acceptance

Before merging:

- `.\tests\smoke.ps1` passes
- audible playback works without the daemon
- daemon playback feels lower-latency than direct playback
- no pet assets are tracked in this repository
- no API keys or generated logs are tracked
