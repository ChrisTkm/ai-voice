param(
    [switch]$Play
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$playerScript = Join-Path $root "ai-voice-player.ps1"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Test-PlayableTarget {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    return [bool](Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in ".wav", ".mp3" } |
        Select-Object -First 1)
}

Assert-True (Test-Path -LiteralPath $playerScript) "Missing ai-voice-player.ps1"
. $playerScript

$requiredScripts = @(
    "claude-notify.ps1",
    "codex-notify.ps1",
    "copilot-notify.ps1",
    "ai-voice-daemon.ps1",
    "generate-narakeet.mjs"
)

foreach ($script in $requiredScripts) {
    Assert-True (Test-Path -LiteralPath (Join-Path $root $script)) "Missing required script: $script"
}

$canonicalIntents = @(
    "notif",
    "complete",
    "stop",
    "thinking",
    "error",
    "permission",
    "warning",
    "blocked",
    "success",
    "long_task",
    "resume",
    "handoff",
    "wakeup",
    "commit",
    "clarify"
)

foreach ($intent in $canonicalIntents) {
    $target = Join-Path $root $intent
    $resolved = $target

    if (-not (Test-PlayableTarget $resolved)) {
        $resolved = Join-Path $root "complete"
    }

    Assert-True (Test-PlayableTarget $resolved) "Intent has no playable target or fallback: $intent"
}

$csvPath = Join-Path $root "narakeet-lines.csv"
$libraryPath = Join-Path $root "voice-library.json"
Assert-True (Test-Path -LiteralPath $csvPath) "Missing narakeet-lines.csv"
Assert-True (Test-Path -LiteralPath $libraryPath) "Missing voice-library.json"

$csvRows = Import-Csv -LiteralPath $csvPath
$library = Get-Content -LiteralPath $libraryPath -Raw | ConvertFrom-Json

foreach ($intent in $canonicalIntents | Where-Object { $_ -ne "stop" }) {
    $csvCount = @($csvRows | Where-Object { $_.intent -eq $intent }).Count
    $libraryCount = @($library.intents.$intent).Count
    Assert-True ($csvCount -gt 0) "No Narakeet rows for intent: $intent"
    Assert-True ($csvCount -eq $libraryCount) "CSV/library count mismatch for intent: $intent"
}

if ($Play) {
    & (Join-Path $root "copilot-notify.ps1") -Intent "complete"
    Assert-True ($LASTEXITCODE -eq 0) "Playback smoke test failed"
}

Write-Host "ai-voice smoke test passed."
