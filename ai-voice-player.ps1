function Get-AiVoiceAudioFile {
    param([Parameter(Mandatory = $true)][string]$Target)

    if (-not (Test-Path -LiteralPath $Target)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
        return $Target
    }

    $wavFiles = @(Get-ChildItem -LiteralPath $Target -Filter "*.wav" -File -ErrorAction SilentlyContinue)
    if ($wavFiles.Count -gt 0) {
        return ($wavFiles | Get-Random).FullName
    }

    $mp3Files = @(Get-ChildItem -LiteralPath $Target -Filter "*.mp3" -File -ErrorAction SilentlyContinue)
    if ($mp3Files.Count -gt 0) {
        return ($mp3Files | Get-Random).FullName
    }

    return $null
}

function New-AiVoiceSilentWavStream {
    param([int]$DurationMs = 180)

    $sampleRate = 8000
    $channels = 1
    $bitsPerSample = 16
    $blockAlign = [int]($channels * $bitsPerSample / 8)
    $byteRate = $sampleRate * $blockAlign
    $dataSize = [int]($sampleRate * $DurationMs / 1000 * $blockAlign)
    $stream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.BinaryWriter]::new($stream, [System.Text.Encoding]::ASCII, $true)

    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $writer.Write([int](36 + $dataSize))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $writer.Write([int]16)
    $writer.Write([short]1)
    $writer.Write([short]$channels)
    $writer.Write([int]$sampleRate)
    $writer.Write([int]$byteRate)
    $writer.Write([short]$blockAlign)
    $writer.Write([short]$bitsPerSample)
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $writer.Write([int]$dataSize)
    $writer.Write([byte[]]::new($dataSize))
    $writer.Flush()
    $stream.Position = 0
    return $stream
}

function Invoke-AiVoiceWarmup {
    param([int]$DurationMs = 180)

    $stream = New-AiVoiceSilentWavStream -DurationMs $DurationMs
    try {
        $player = [System.Media.SoundPlayer]::new($stream)
        $player.Load()
        $player.PlaySync()
    } finally {
        if ($player) {
            $player.Dispose()
        }
        $stream.Dispose()
    }
}

function Invoke-AiVoicePlayback {
    param([Parameter(Mandatory = $true)][string]$Target)

    $path = Get-AiVoiceAudioFile -Target $Target
    if (-not $path) {
        return 3
    }

    $extension = [System.IO.Path]::GetExtension($path).ToLowerInvariant()

    if ($extension -eq ".wav") {
        Invoke-AiVoiceWarmup
        $player = [System.Media.SoundPlayer]::new($path)
        try {
            $player.Load()
            $player.PlaySync()
            return 0
        } finally {
            $player.Dispose()
        }
    }

    if (-not ("AiVoice.Mci" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace AiVoice {
    public static class Mci {
        [DllImport("winmm.dll", CharSet = CharSet.Auto)]
        public static extern int SendString(string command, StringBuilder buffer, int bufferSize, IntPtr hwndCallback);
    }
}
"@
    }

    $alias = "a" + [Environment]::TickCount
    $open = "open `"$path`" type mpegvideo alias $alias"
    $rc = [AiVoice.Mci]::SendString($open, $null, 0, [IntPtr]::Zero)
    if ($rc -ne 0) { return 2 }

    $length = [System.Text.StringBuilder]::new(64)
    [AiVoice.Mci]::SendString("status $alias length", $length, 64, [IntPtr]::Zero) | Out-Null
    $ms = 3000
    $parsed = 0
    if ([int]::TryParse($length.ToString(), [ref]$parsed)) {
        $ms = $parsed + 80
    }

    [AiVoice.Mci]::SendString("play $alias", $null, 0, [IntPtr]::Zero) | Out-Null
    Start-Sleep -Milliseconds $ms
    [AiVoice.Mci]::SendString("close $alias", $null, 0, [IntPtr]::Zero) | Out-Null
    return 0
}

function Get-AiVoiceRuntimeDir {
    param([Parameter(Mandatory = $true)][string]$Root)

    return (Join-Path $Root ".ai-voice-runtime")
}

function Test-AiVoiceDaemon {
    param([Parameter(Mandatory = $true)][string]$Root)

    $runtimeDir = Get-AiVoiceRuntimeDir -Root $Root
    $pidFile = Join-Path $runtimeDir "daemon.pid"

    if (-not (Test-Path -LiteralPath $pidFile)) {
        return $false
    }

    try {
        $daemonPid = [int](Get-Content -LiteralPath $pidFile -Raw)
        return [bool](Get-Process -Id $daemonPid -ErrorAction SilentlyContinue)
    } catch {
        return $false
    }
}

function Send-AiVoiceRequest {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Intent,
        [string]$Event = ""
    )

    if (-not (Test-AiVoiceDaemon -Root $Root)) {
        return $false
    }

    try {
        $runtimeDir = Get-AiVoiceRuntimeDir -Root $Root
        $queueDir = Join-Path $runtimeDir "queue"
        New-Item -ItemType Directory -Force -Path $queueDir | Out-Null

        $id = "{0:yyyyMMddHHmmssfff}-{1}-{2}" -f (Get-Date), $PID, ([Guid]::NewGuid().ToString("N"))
        $tmpFile = Join-Path $queueDir "$id.tmp"
        $queueFile = Join-Path $queueDir "$id.json"
        $payload = [ordered]@{
            intent = $Intent
            event = $Event
            createdAt = (Get-Date).ToString("o")
        }

        $payload | ConvertTo-Json -Compress | Set-Content -LiteralPath $tmpFile -Encoding UTF8
        Move-Item -LiteralPath $tmpFile -Destination $queueFile -Force
        return $true
    } catch {
        return $false
    }
}
