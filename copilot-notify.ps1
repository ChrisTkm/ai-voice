param(
    [string]$Intent = "",
    [string]$NotificationJson = ""
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$player = Join-Path $root "play.exe"
$logFile = Join-Path $root "copilot-notify.log"

function Write-NotifyLog {
    param([string]$Message)
    try {
        $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $logFile -Value "[$stamp] $Message"
    } catch {
    }
}

if (-not (Test-Path -LiteralPath $player)) {
    Write-NotifyLog "missing player: $player"
    exit 0
}

# Resolve intent from JSON payload if provided
if ($NotificationJson) {
    try {
        $payload = $NotificationJson | ConvertFrom-Json

        if (-not $Intent -and $payload.intent) {
            $Intent = [string]$payload.intent
        }
        if (-not $Intent -and $payload.sound) {
            $Intent = [string]$payload.sound
        }

        # Map VS Code / Copilot event types to intents
        if (-not $Intent -and $payload.event) {
            switch ([string]$payload.event) {
                "chat.submit"          { $Intent = "thinking"; break }
                "chat.response"        { $Intent = "complete"; break }
                "chat.stop"            { $Intent = "stop";     break }
                "inline.accept"        { $Intent = "success";  break }
                "inline.reject"        { $Intent = "stop";     break }
                "task.start"           { $Intent = "long_task"; break }
                "task.complete"        { $Intent = "complete"; break }
                "task.error"           { $Intent = "error";    break }
                "agent.handoff"        { $Intent = "handoff";  break }
                "agent.blocked"        { $Intent = "blocked";  break }
                "agent.permission"     { $Intent = "permission"; break }
                default               { }
            }
        }
    } catch {
        # Ignore parse errors
    }
}

if (-not $Intent) { exit 0 }

$soundTarget = Join-Path $root $Intent
$fallbackTarget = Join-Path $root "stop"

if (-not (Test-Path -LiteralPath $soundTarget) -or -not (Get-ChildItem -LiteralPath $soundTarget -Filter "*.mp3" -File -ErrorAction SilentlyContinue)) {
    Write-NotifyLog "fallback intent=$Intent target=$soundTarget"
    $soundTarget = $fallbackTarget
}

if (-not (Test-Path -LiteralPath $soundTarget) -or -not (Get-ChildItem -LiteralPath $soundTarget -Filter "*.mp3" -File -ErrorAction SilentlyContinue)) {
    Write-NotifyLog "no playable target intent=$Intent"
    exit 0
}

& $player $soundTarget
$playExit = $LASTEXITCODE
Write-NotifyLog "played intent=$Intent target=$soundTarget exit=$playExit"
