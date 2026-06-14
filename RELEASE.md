# ai-voice release notes

## v0.1.0 release intent

This release is built on `release/v0.1.0`. Merge into `main` only after validation is done.

The release goal is to make `ai-voice` a lightweight passive audio layer:

- local clone, local WAV files, local PowerShell scripts
- no pet runtime in this repo
- pet prototypes live in `C:\dev\Nostromo\studio\pets`
- no dynamic TTS during normal notification playback
- no marketplace requirement for v0.1.0
- one notify command from each host integration
- resident daemon as the preferred low-latency path
- direct playback as the fallback when the daemon is not running

## Validation checklist

Before merging to `main`:

1. Run `.\tests\smoke.ps1`.
2. Run `.\copilot-notify.ps1 -Intent complete`.
3. Start `.\ai-voice-daemon.ps1`.
4. Trigger `complete`, `permission`, `error`, and `blocked` through `copilot-notify.ps1`.
5. Confirm hooks return quickly when the daemon is running.
6. Confirm no pet assets are tracked in the release.
7. Confirm no API keys, logs, or runtime queue files are tracked.

See [`TESTING.md`](TESTING.md) and [`SECURITY.md`](SECURITY.md) for the full lightweight checklist.

## Audio expansion rule

Adding more phrases to existing intents is allowed without changing the system design. Add rows to `narakeet-lines.csv`, mirror them in `voice-library.json`, and run `node .\generate-narakeet.mjs` without `--overwrite` so only missing clips are generated.

Adding new intents requires updating routing, docs, tests, and integration guidance.
