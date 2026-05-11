param(
    [Parameter(Position = 0)]
    [string]$NotificationJson = "",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs = @()
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$player = Join-Path $root "play.exe"
$logFile = Join-Path $root "codex-notify.log"

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

$payload = $null
$eventType = ""

if (-not $NotificationJson -and $RemainingArgs.Count -gt 0) {
    $NotificationJson = ($RemainingArgs -join " ")
}

if (-not $NotificationJson) {
    try {
        if ([Console]::IsInputRedirected) {
            $NotificationJson = [Console]::In.ReadToEnd()
        }
    } catch {
        $NotificationJson = ""
    }
}

if ($NotificationJson) {
    try {
        $payload = $NotificationJson | ConvertFrom-Json
        $eventType = [string]$payload.type
    } catch {
        Write-NotifyLog "invalid json"
        $eventType = ""
    }
}

$intent = ""
if ($payload -and $payload.intent) {
    $intent = [string]$payload.intent
} elseif ($payload -and $payload.sound) {
    $intent = [string]$payload.sound
}

if (-not $intent) {
    switch ($eventType) {
        "agent-turn-user-prompt" { $intent = "notif"; break }
        "agent-turn-complete" { $intent = "complete"; break }
        "agent-turn-stop" { $intent = "stop"; break }
        default { $intent = "stop" }
    }
}

$soundTarget = Join-Path $root $intent
$fallbackTarget = Join-Path $root "stop"

if (-not (Test-Path -LiteralPath $soundTarget) -or -not (Get-ChildItem -LiteralPath $soundTarget -Filter "*.mp3" -File -ErrorAction SilentlyContinue)) {
    Write-NotifyLog "fallback intent=$intent event=$eventType target=$soundTarget"
    $soundTarget = $fallbackTarget
}

if (-not (Test-Path -LiteralPath $soundTarget) -or -not (Get-ChildItem -LiteralPath $soundTarget -Filter "*.mp3" -File -ErrorAction SilentlyContinue)) {
    Write-NotifyLog "no playable target intent=$intent event=$eventType"
    exit 0
}

& $player $soundTarget
$playExit = $LASTEXITCODE
Write-NotifyLog "played intent=$intent event=$eventType target=$soundTarget exit=$playExit"
