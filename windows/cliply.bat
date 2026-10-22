@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title CLIPLY - created by @cauerast
set "DOWNLOAD_DIR=%USERPROFILE%\Downloads"
mode con cols=94 lines=38 >nul 2>nul

:check
cls
call :header
echo  SYSTEM CHECK
echo  ------------------------------------------------------------
where yt-dlp >nul 2>nul
if errorlevel 1 (
  echo  [INFO] Installing yt-dlp using WinGet...
  where winget >nul 2>nul
  if errorlevel 1 (
    echo  [ERROR] WinGet is missing. Install App Installer first.
    goto dependency_failed
  )
  winget install --id yt-dlp.yt-dlp -e --accept-source-agreements --accept-package-agreements
  if errorlevel 1 goto dependency_failed
  ) else echo  [OK] yt-dlp installed.
  where ffmpeg >nul 2>nul
  if errorlevel 1 (
    echo  [INFO] Installing FFmpeg using WinGet...
    where winget >nul 2>nul
    if errorlevel 1 goto dependency_failed
    winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
    if errorlevel 1 goto dependency_failed
    ) else echo  [OK] FFmpeg installed.
    set "PATH=%LOCALAPPDATA%\Microsoft\WinGet\Links;%PATH%"
    where yt-dlp >nul 2>nul
    if errorlevel 1 goto dependency_failed
    where ffmpeg >nul 2>nul
    if errorlevel 1 goto dependency_failed
    where ffprobe >nul 2>nul
    if errorlevel 1 goto dependency_failed
    echo.
    echo  [READY] Dependencies detected.
    echo  Press any key to continue...
    pause >nul
    goto menu
    
    :dependency_failed
    echo.
    echo  [ERROR] Dependencies unavailable. Restart Terminal after installing,
    echo  then run this file again.
    pause >nul
    exit /b 1
    
    :header
    echo.
    echo.
    echo  +------------------------------------------------------------+
    echo  ^|           CLIPLY         ^|
    echo  ^|  VIDEO  /  AUDIO  /  4K  ^|
    echo  +------------------------------------------------------------+
    echo.
    echo  created by @cauerast  -  Windows edition
    echo.
    exit /b
    
    :menu
    cls
    call :header
    echo  +------------------------------------------------------------+
    echo  ^|  [1] Video  - MP4 / best available quality  ^|
    echo  ^|  [2] Trim video  - MP4 / best available quality  ^|
    echo  ^|  [3] Audio  - MP3 / 320 kbps output  ^|
    echo  ^|  [4] Trim audio  - MP3 / 320 kbps output  ^|
    echo  ^|  [5] Audio  - WAV / uncompressed output  ^|
    echo  ^|  [6] Trim audio  - WAV / uncompressed output  ^|
    echo  +------------------------------------------------------------+
    echo.
    echo  Save location: %DOWNLOAD_DIR%
    echo  Press ENTER at the link prompt to exit.
    echo.
    set "VIDEO_URL="
    set /p "VIDEO_URL=              Paste video or playlist URL: "
    if not defined VIDEO_URL goto finish
    set "PLAYLIST_OPT=--no-playlist"
    set "CUT_PARAM="
    set "SUFFIX="
    set "IS_LIST="
    
    :: Detect playlist parameters using batch string replacement (no URL execution).
    if not "%VIDEO_URL:list=_%"=="%VIDEO_URL%" set "IS_LIST=1"
    if not "%VIDEO_URL:start_radio=_%"=="%VIDEO_URL%" set "IS_LIST=1"
    if not defined IS_LIST goto format
    
    echo.
    echo  [INFO] Playlist / mix link detected.
    set "PL_CHOICE="
    set /p "PL_CHOICE=              [1] Current item / [2] entire playlist [1]: "
    if "%PL_CHOICE%"=="2" set "PLAYLIST_OPT=--yes-playlist"
    
    :format
    echo.
    set "FORMAT="
    set /p "FORMAT=              Select format [1-6, default 1]: "
    if not defined FORMAT set "FORMAT=1"
    if "%FORMAT%"=="1" goto video
    if "%FORMAT%"=="2" goto trim
    if "%FORMAT%"=="3" goto mp3
    if "%FORMAT%"=="4" goto trim
    if "%FORMAT%"=="5" goto wav
    if "%FORMAT%"=="6" goto trim
    echo  [ERROR] Invalid selection.
    pause >nul
    goto menu
    
    :trim
    set "CUT_START="
    set "CUT_END="
    echo  Time format: MM:SS or HH:MM:SS.
    set /p "CUT_START=              Start time: "
    set /p "CUT_END=              End time: "
    :: Time validation is performed by PowerShell, available on Windows 10/11.
    powershell -NoProfile -Command "$a='%CUT_START%';$b='%CUT_END%'; if($a -notmatch '^(\d+:)?\d{1,2}:[0-5]\d$' -or $b -notmatch '^(\d+:)?\d{1,2}:[0-5]\d$'){exit 1};try{$x=[TimeSpan]::Parse($a);$y=[TimeSpan]::Parse($b);if($x -ge $y){exit 1}}catch{exit 1}" >nul 2>nul
    if errorlevel 1 (
      echo  [ERROR] Invalid time range.
      pause >nul
      goto menu
    )
    set "CUT_PARAM=--download-sections"
    set "SUFFIX= [Trimmed]"
    if "%FORMAT%"=="2" goto video
    if "%FORMAT%"=="4" goto mp3
    goto wav
    
    :video
    set "OUTPUT=%%(title)s%SUFFIX% [%%(resolution)s].%%(ext)s"
    set "DLP_ARGS=-f bv*+ba/b --merge-output-format mp4 --remux-video mp4 --embed-metadata --embed-chapters"
    goto run
    
    :mp3
    set "OUTPUT=%%(title)s%SUFFIX% [Audio].%%(ext)s"
    set "DLP_ARGS=-f bestaudio/best -x --audio-format mp3 --audio-quality 320K --embed-metadata --embed-thumbnail"
    goto run
    
    :wav
    set "OUTPUT=%%(title)s%SUFFIX% [Audio].%%(ext)s"
    set "DLP_ARGS=-f bestaudio/best -x --audio-format wav --embed-metadata"
    goto run
    
    :run
    echo.
    echo  ------------------------------------------------------------
    echo  Downloading...
    echo.
    if defined CUT_PARAM goto run_trim
    yt-dlp --newline --progress --no-overwrites %PLAYLIST_OPT% %DLP_ARGS% -P "%DOWNLOAD_DIR%" -o "%OUTPUT%" "%VIDEO_URL%"
    goto result
    
    :run_trim
    yt-dlp --newline --progress --no-overwrites %PLAYLIST_OPT% --download-sections "*%CUT_START%-%CUT_END%" %DLP_ARGS% -P "%DOWNLOAD_DIR%" -o "%OUTPUT%" "%VIDEO_URL%"
    
    :result
    if errorlevel 1 (
      echo.
      echo  [ERROR] Download failed. See output above.
      echo  Try: winget upgrade yt-dlp.yt-dlp
      ) else (
      echo.
      echo  [SUCCESS] Finished. Check your Downloads folder.
    )
    echo.
    echo  Press any key to return to menu...
    pause >nul
    goto menu
    
    :finish
    echo.
    echo  Thanks for using CLIPLY <3 !
    exit /b 0
