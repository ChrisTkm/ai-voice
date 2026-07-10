param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [int]$PollMs = 100,
    [int]$WarmupIntervalSeconds = 20,
    [int]$MaxQueueAgeMinutes = 10
)

$playerScript = Join-Path $Root "ai-voice-player.ps1"
$logFile = Join-Path $Root "ai-voice-daemon.log"

. $playerScript

function Write-DaemonLog {
    param([string]$Message)
    try {
        $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $logFile -Value "[$stamp] $Message"
    } catch {
    }
}

$runtimeDir = Get-AiVoiceRuntimeDir -Root $Root
$queueDir = Join-Path $runtimeDir "queue"
$pidFile = Join-Path $runtimeDir "daemon.pid"
$eventFile = Join-Path $runtimeDir "last_event.json"

New-Item -ItemType Directory -Force -Path $queueDir | Out-Null
Set-Content -LiteralPath $pidFile -Value $PID -Encoding ASCII
Write-DaemonLog "started pid=$PID root=$Root"

function Write-AiVoiceLastEvent {
    param(
        [string]$Intent,
        [string]$Event,
        [int]$ExitCode
    )
    try {
        $payload = [ordered]@{
            intent = $Intent
            event  = $Event
            exit   = $ExitCode
            ts     = (Get-Date).ToUniversalTime().ToString("o")
        }
        $tmp = "$eventFile.tmp"
        $payload | ConvertTo-Json -Compress | Set-Content -LiteralPath $tmp -Encoding UTF8
        Move-Item -LiteralPath $tmp -Destination $eventFile -Force
    } catch {
        Write-DaemonLog "last_event write failed: $($_.Exception.Message)"
    }
}

$lastWarmup = [DateTime]::MinValue

try {
    while ($true) {
        $now = Get-Date
        if (($now - $lastWarmup).TotalSeconds -ge $WarmupIntervalSeconds) {
            try {
                Invoke-AiVoiceWarmup
            } catch {
                Write-DaemonLog "warmup failed: $($_.Exception.Message)"
            }
            $lastWarmup = $now
        }

        $items = @(Get-ChildItem -LiteralPath $queueDir -Filter "*.json" -File -ErrorAction SilentlyContinue |
            Sort-Object CreationTimeUtc)

        foreach ($item in $items) {
            try {
                $payload = Get-Content -LiteralPath $item.FullName -Raw | ConvertFrom-Json
                $intent = [string]$payload.intent
                $createdAtUtc = $item.CreationTimeUtc

                if ($payload.createdAt) {
                    try {
                        $createdAtUtc = ([DateTimeOffset]::Parse([string]$payload.createdAt)).UtcDateTime
                    } catch {
                    }
                }

                if ($MaxQueueAgeMinutes -gt 0 -and ((Get-Date).ToUniversalTime() - $createdAtUtc).TotalMinutes -gt $MaxQueueAgeMinutes) {
                    Write-DaemonLog "dropped stale intent=$intent event=$($payload.event) file=$($item.Name)"
                    continue
                }

                if ($intent) {
                    $target = Join-Path $Root $intent
                    $exitCode = Invoke-AiVoicePlayback -Target $target
                    Write-DaemonLog "played intent=$intent event=$($payload.event) exit=$exitCode"
                    Write-AiVoiceLastEvent -Intent $intent -Event ([string]$payload.event) -ExitCode $exitCode
                }
            } catch {
                Write-DaemonLog "request failed file=$($item.Name) error=$($_.Exception.Message)"
            } finally {
                Remove-Item -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue
            }
        }

        Start-Sleep -Milliseconds $PollMs
    }
} finally {
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    Write-DaemonLog "stopped pid=$PID"
}
