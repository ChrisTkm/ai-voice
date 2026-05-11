$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$player = Join-Path $root "play.exe"
$playerSource = Join-Path $root "play.cs"
$logFile = Join-Path $root "claude-notify.log"

function Write-NotifyLog {
    param([string]$Message)
    try {
        $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $logFile -Value "[$stamp] $Message"
    } catch {
    }
}

function Ensure-Player {
    $shouldCompile = -not (Test-Path -LiteralPath $player)

    if (-not $shouldCompile -and (Test-Path -LiteralPath $playerSource)) {
        $shouldCompile = (Get-Item -LiteralPath $playerSource).LastWriteTimeUtc -gt (Get-Item -LiteralPath $player).LastWriteTimeUtc
    }

    if (-not $shouldCompile) {
        return $true
    }

    if (-not (Test-Path -LiteralPath $playerSource)) {
        Write-NotifyLog "missing player source: $playerSource"
        return $false
    }

    try {
        Add-Type -Path $playerSource -OutputAssembly $player -OutputType ConsoleApplication | Out-Null
        Write-NotifyLog "compiled player: $player"
        return (Test-Path -LiteralPath $player)
    } catch {
        Write-NotifyLog "player compile failed: $($_.Exception.Message)"
        return $false
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

if (-not (Ensure-Player)) {
    Write-NotifyLog "missing player: $player"
    exit 0
}

$stdinText = ""
try {
    $stdinText = [Console]::In.ReadToEnd()
} catch {
    $stdinText = ""
}

$payload = $null
if ($stdinText) {
    try {
        $payload = $stdinText | ConvertFrom-Json
    } catch {
        $payload = $null
    }
}

$intent = ""

if ($payload) {
    $event = [string]$payload.hook_event_name

    switch ($event) {
        "Notification" {
            $msg = [string]$payload.message
            if ($msg -match "(?i)permission") {
                $intent = "permission"
            } else {
                $intent = "notif"
            }
            break
        }
        "Stop"         { $intent = "complete"; break }
        "SubagentStop" { $intent = "handoff";  break }
        "SessionStart" {
            $source = [string]$payload.source
            switch ($source) {
                "startup" { $intent = "wakeup"; break }
                "resume"  { $intent = "resume"; break }
                default   { $intent = ""       }
            }
            break
        }
        "PostToolUse" {
            $tool = [string]$payload.tool_name
            if ($tool -eq "Bash") {
                $cmd = [string]$payload.tool_input.command
                if ($cmd -match "git\s+commit") {
                    $intent = "commit"
                }
            }
            break
        }
        default { }
    }
}

if (-not $intent) { exit 0 }

$soundTarget = Join-Path $root $intent

if (-not (Test-PlayableTarget $soundTarget)) {
    Write-NotifyLog "fallback intent=$intent target=$soundTarget"
    $soundTarget = Join-Path $root "stop"
}

if (-not (Test-PlayableTarget $soundTarget)) {
    Write-NotifyLog "no playable target intent=$intent"
    exit 0
}

& $player $soundTarget
$playExit = $LASTEXITCODE
Write-NotifyLog "played intent=$intent event=$event target=$soundTarget exit=$playExit"
