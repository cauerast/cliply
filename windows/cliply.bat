@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title CLIPLY - created by @cauerast
set "CLIPLY_SELF=%~f0"
set "CLIPLY_PS=%TEMP%\cliply-%RANDOM%-%RANDOM%.ps1"
powershell.exe -NoProfile -Command "$p=$env:CLIPLY_SELF; $o=$env:CLIPLY_PS; $s=[IO.File]::ReadAllText($p); $mark='# POWERSHELL_PAYLOAD_START'; $i=$s.IndexOf($mark); if($i -lt 0){exit 1}; [IO.File]::WriteAllText($o,$s.Substring($i+$mark.Length).TrimStart([char]13,[char]10),[Text.UTF8Encoding]::new($true))"
if errorlevel 1 (
  echo Could not launch Cliply. Windows PowerShell 5.1 is required.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CLIPLY_PS%"
set "CLIPLY_RC=%ERRORLEVEL%"
del /q "%CLIPLY_PS%" >nul 2>nul
exit /b %CLIPLY_RC%
# POWERSHELL_PAYLOAD_START
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Host.UI.RawUI.WindowTitle = 'CLIPLY - created by @cauerast'
$downloadDir = Join-Path $env:USERPROFILE 'Downloads'
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
$env:PATH = "$env:LOCALAPPDATA\Microsoft\WinGet\Links;$env:PATH"

function C([string]$s, [string]$color = 'Gray') {
    $w = try { [Console]::WindowWidth } catch { 80 }
    $spaces = [Math]::Max(0, [int][Math]::Floor(($w - $s.Length) / 2))
    Write-Host ((' ' * $spaces) + $s) -ForegroundColor $color
}
function Header {
    Clear-Host
    Write-Host ''
    C '+--------------------------------------------------------------+' Cyan
    C '|                            CLIPLY                            |' Cyan
    C '|                 VIDEO  /  AUDIO  /  4K                       |' Cyan
    C '+--------------------------------------------------------------+' Cyan
    Write-Host ''
    C 'created by @cauerast  -  Windows edition' DarkGray
    Write-Host ''
}
function Note([string]$s, [string]$color='White') { Write-Host "  $s" -ForegroundColor $color }
function Pause-Menu { Write-Host ''; Note 'Press any key to return...' DarkGray; [void][Console]::ReadKey($true) }
function Read-Key([string]$prompt, [string]$allowed) {
    Write-Host "  $prompt" -NoNewline -ForegroundColor White
    while ($true) {
        $k = [Console]::ReadKey($true).KeyChar.ToString()
        if ($k -eq "`r") { $k = '1' }
        if ($allowed.Contains($k)) { Write-Host $k -ForegroundColor Cyan; return $k }
    }
}
function Check-Tools {
    $missing = @('yt-dlp', 'ffmpeg', 'ffprobe') | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) }
    if (-not $missing) { return $true }
    Header
    Note ('Missing dependencies: ' + ($missing -join ', ')) Yellow
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Note 'Install WinGet (App Installer), then install yt-dlp and FFmpeg.' Red
        return $false
    }
    Note 'Installing missing packages with WinGet...' Yellow
    if ($missing -contains 'yt-dlp') { & winget install --id yt-dlp.yt-dlp -e --accept-source-agreements --accept-package-agreements }
    if (($missing -contains 'ffmpeg') -or ($missing -contains 'ffprobe')) { & winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements }
    Note 'Restart this terminal if the new tools are not found.' Yellow
    return (-not (@('yt-dlp', 'ffmpeg', 'ffprobe') | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) }))
}
function Seconds([string]$v) {
    if ($v -notmatch '^([0-9]+):([0-5][0-9])(:([0-5][0-9]))?$') { return -1 }
    if ($Matches[3]) { return ([double]$Matches[1] * 3600 + [int]$Matches[2] * 60 + [int]$Matches[4]) }
    return ([double]$Matches[1] * 60 + [int]$Matches[2])
}
function Quote-Arg([string]$arg) {
    # Windows CreateProcess escaping, including trailing backslashes.
    if ($arg -notmatch '[\s"]' ) { return $arg }
    $value = [regex]::Replace($arg, '(\\*)"', { param($m) ($m.Groups[1].Value * 2) + '\"' })
    $value = [regex]::Replace($value, '(\\+)$', { param($m) $m.Value + $m.Value })
    return '"' + $value + '"'
}
function Render-Bar([int]$pct, [string]$label) {
    $pct = [Math]::Max(0, [Math]::Min(100, $pct))
    $filled = [int][Math]::Floor($pct * 0.32)
    $bar = ('#' * $filled) + ('-' * (32 - $filled))
    $width = try { [Console]::WindowWidth } catch { 90 }
    $line = "  $label [$bar] $pct%"
    if ($line.Length -ge $width) { $line = $line.Substring(0, [Math]::Max(1,$width-1)) }
    Write-Host ("`r" + $line.PadRight([Math]::Max(1,$width-1))) -NoNewline -ForegroundColor Cyan
}
function Run-Process([string]$executable, [string[]]$arguments, [string]$label, [string]$workDir, [bool]$hasProgress) {
    $stdOut = Join-Path $workDir ('out-' + [guid]::NewGuid().ToString('N') + '.log')
    $stdErr = Join-Path $workDir ('err-' + [guid]::NewGuid().ToString('N') + '.log')
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = (Get-Command $executable -ErrorAction Stop).Source
    $info.Arguments = (($arguments | ForEach-Object { Quote-Arg ([string]$_) }) -join ' ')
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($info)
    $stdout = [IO.StreamWriter]::new($stdOut, $false)
    $stderr = [IO.StreamWriter]::new($stdErr, $false)
    # Drain both streams concurrently; never block yt-dlp or FFmpeg.
    $copyOut = $p.StandardOutput.BaseStream.CopyToAsync($stdout.BaseStream)
    $copyErr = $p.StandardError.BaseStream.CopyToAsync($stderr.BaseStream)
    $percent = 0
    $spinner = 0
    try {
        while (-not $p.HasExited) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true).KeyChar
                if ($key -eq 'q' -or $key -eq 'Q') {
                    try { & taskkill /PID $p.Id /T /F 2>$null | Out-Null } catch {}
                    return @{ Cancelled=$true; Success=$false; Stdout=$stdOut; Stderr=$stdErr }
                }
            }
            if ($hasProgress) {
                try {
                    $matchLines = Get-Content -LiteralPath $stdErr -Tail 12 -ErrorAction SilentlyContinue
                    foreach ($l in $matchLines) {
                        if ($l -match 'CLIPLY_PROGRESS:([0-9]+(?:\.[0-9]+)?)%') { $percent = [Math]::Max($percent, [int][double]::Parse($Matches[1],[cultureinfo]::InvariantCulture)) }
                    }
                } catch {}
                Render-Bar $percent $label
            } else {
                $spin = @('|','/','-','\')[$spinner++ % 4]
                Write-Host "`r  $label $spin  (press q to cancel)    " -NoNewline -ForegroundColor Yellow
            }
            Start-Sleep -Milliseconds 180
            $p.Refresh()
        }
        $p.WaitForExit()
        $success = ($p.ExitCode -eq 0)
        if ($hasProgress -and $success) { Render-Bar 100 $label }
        Write-Host ''
        return @{ Cancelled=$false; Success=$success; Stdout=$stdOut; Stderr=$stdErr }
    } finally {
        try { if (-not $p.HasExited) { $p.WaitForExit(1500) | Out-Null } } catch {}
        try { [System.Threading.Tasks.Task]::WaitAll(@($copyOut,$copyErr), 1500) | Out-Null } catch {}
        $stdout.Dispose(); $stderr.Dispose(); $p.Dispose()
    }
}
function Safe-Name([string]$name) {
    $name = $name -replace '[<>:"/\\|?*\x00-\x1f]', '_'
    $name = $name.Trim(' ', '.')
    if ($name.Length -gt 120) { $name = $name.Substring(0,120) }
    if (-not $name) { $name = 'Cliply video' }
    return $name
}
function Get-FreePath([string]$name, [string]$ext) {
    $path = Join-Path $downloadDir ($name + $ext)
    $n=1
    while (Test-Path -LiteralPath $path) { $path = Join-Path $downloadDir ("$name ($n)$ext"); $n++ }
    return $path
}
function Download([string]$url, [string]$mode, [bool]$playlist, [string]$start, [string]$end) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('cliply-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temp | Out-Null
    $cancelled = $false
    try {
        $opt = @('--no-colors','--newline','--progress','--no-overwrites','--no-part','--progress-template','download:CLIPLY_PROGRESS:%(progress._percent_str)s','-P',$temp,'-o','%(title).120s [%(id)s].%(ext)s')
        if ($playlist) { $opt += '--yes-playlist' } else { $opt += '--no-playlist' }
        if ($start) { $opt += @('--download-sections',"*$start-$end") }
        switch ($mode) {
            { $_ -in '1','2' } { $opt += @('-f','bv+ba/b','--merge-output-format','mkv'); break }
            { $_ -in '3','4' } { $opt += @('-f','bestaudio/best','-x','--audio-format','mp3','--audio-quality','320K','--embed-metadata','--embed-thumbnail'); break }
            default { $opt += @('-f','bestaudio/best','-x','--audio-format','wav','--embed-metadata') }
        }
        $opt += @('--',$url)
        Note 'Press q to cancel the download.' DarkGray
        $r = Run-Process 'yt-dlp' $opt 'Downloading' $temp $true
        if ($r.Cancelled) { Note 'Cancelled. Temporary files removed.' Yellow; return }
        if (-not $r.Success) { Note 'Download failed. Update yt-dlp or check the URL.' Red; Get-Content -LiteralPath $r.Stderr -Tail 5 -ErrorAction SilentlyContinue; return }
        $media = @(Get-ChildItem -LiteralPath $temp -File | Where-Object { $_.Extension -notin '.log','.part','.ytdl','.json','.jpg','.jpeg','.png','.webp' })
        if (-not $media) { Note 'No completed media file found.' Red; return }
        foreach ($item in $media) {
            $base = Safe-Name ([IO.Path]::GetFileNameWithoutExtension($item.Name))
            if ($mode -in '2','4','6') { $base += ' [Trimmed]' }
            if ($mode -in '1','2') {
                $destination = Get-FreePath $base '.mp4'
                Note 'Encoding compatible MP4 (H.264 + AAC). This can take time...' DarkGray
                $ffargs = @('-hide_banner','-loglevel','error','-y','-i',$item.FullName,'-map','0:v:0','-map','0:a:0','-c:v','libx264','-preset','medium','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart', $destination)
                # Avoid exposing partial final files if cancellation occurs.
                $r2 = Run-Process 'ffmpeg' $ffargs 'Encoding' $temp $false
                if ($r2.Cancelled) { Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue; Note 'Cancelled.' Yellow; return }
                if (-not $r2.Success) { Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue; Note 'Encoding failed.' Red; Get-Content $r2.Stderr -Tail 5; return }
            } else {
                $destination = Get-FreePath $base $item.Extension
                Move-Item -LiteralPath $item.FullName -Destination $destination
            }
            Note ('Saved: ' + (Split-Path $destination -Leaf)) Green
        }
        Note 'Finished. Check your Downloads folder.' Green
    } finally { Remove-Item -LiteralPath $temp -Force -Recurse -ErrorAction SilentlyContinue }
}
if (-not (Check-Tools)) { Pause-Menu; exit 1 }
while ($true) {
    Header
    C '01  Video                MP4 / H.264 + AAC' Magenta
    C '02  Trim video           MP4 / H.264 + AAC' Magenta
    C '03  Audio                MP3 / 320 kbps output' Magenta
    C '04  Trim audio           MP3 / 320 kbps output' Magenta
    C '05  Audio                WAV / uncompressed output' Magenta
    C '06  Trim audio           WAV / uncompressed output' Magenta
    Write-Host ''
    C '--------------------------------------------------------------' DarkGray
    C ('Save location: ' + $downloadDir) DarkGray
    C 'Press ENTER at the URL prompt to exit' DarkGray
    Write-Host ''
    $url = Read-Host '  Paste video or playlist URL'
    if (-not $url) { break }
    $uri = $null
    if (-not [Uri]::TryCreate($url,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -notin @('http','https')) { Note 'Enter a valid http(s) URL.' Red; Pause-Menu; continue }
    $playlist = $false
    if ($url -match '(?:[?&]list=|[?&]start_radio=)') { $playlist = (Read-Key 'Playlist detected. [1] Current / [2] Entire list: ' '12') -eq '2' }
    $mode = Read-Key 'Select format: ' '123456'
    $start=''; $end=''
    if ($mode -in '2','4','6') {
        $start = Read-Host '  Start (MM:SS or HH:MM:SS)'
        $end = Read-Host '  End   (MM:SS or HH:MM:SS)'
        if ((Seconds $start) -lt 0 -or (Seconds $end) -le (Seconds $start)) { Note 'Invalid time range.' Red; Pause-Menu; continue }
    }
    try { Download $url $mode $playlist $start $end }
    catch { Note ('Error: ' + $_.Exception.Message) Red }
    Pause-Menu
}
Note 'Thanks for using CLIPLY <3 !' Cyan