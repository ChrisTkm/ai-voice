param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [int]$PollMs = 100,
    [int]$WarmupIntervalSeconds = 20
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

New-Item -ItemType Directory -Force -Path $queueDir | Out-Null
Set-Content -LiteralPath $pidFile -Value $PID -Encoding ASCII
Write-DaemonLog "started pid=$PID root=$Root"

$lastWarmup = [DateTime]::MinValue

try {
    while ($true) {
        $now = Get-Date
        if (($now - $lastWarmup).TotalSeconds -ge $WarmupIntervalSeconds) {
            Invoke-AiVoiceWarmup
            $lastWarmup = $now
        }

        $items = @(Get-ChildItem -LiteralPath $queueDir -Filter "*.json" -File -ErrorAction SilentlyContinue |
            Sort-Object CreationTimeUtc)

        foreach ($item in $items) {
            try {
                $payload = Get-Content -LiteralPath $item.FullName -Raw | ConvertFrom-Json
                $intent = [string]$payload.intent

                if ($intent) {
                    $target = Join-Path $Root $intent
                    $exitCode = Invoke-AiVoicePlayback -Target $target
                    Write-DaemonLog "played intent=$intent event=$($payload.event) exit=$exitCode"
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
