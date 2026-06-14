# Security and privacy

`ai-voice` is designed as a local passive audio layer.

## Runtime behavior

- Normal playback uses local scripts and local audio files.
- Notify scripts accept small event payloads or explicit intent names.
- Notify scripts do not send event payloads to external services.
- Logs are local and ignored by Git.
- Runtime queue files are local and ignored by Git.

## Narakeet API key

`NARAKEET_API_KEY` is only needed when generating new audio clips with `generate-narakeet.mjs`.

Do not commit API keys. Set the key in the current shell:

```powershell
$env:NARAKEET_API_KEY = "<your-real-narakeet-api-key>"
```

The generator refuses common placeholder values, but it cannot protect against accidentally pasting a real key into a tracked file. Keep keys in the environment or in ignored local files only.

## Host integrations

External tools should call one of the notify scripts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\dev\ai-voice\copilot-notify.ps1" -Intent complete
```

Do not move audio routing rules into the host application. Keeping routing in this repository makes reviews and security checks simpler.

## Reporting issues

For now, report security issues privately to the repository owner before opening a public issue.
