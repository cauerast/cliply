#!/usr/bin/env bash
# CLIPLY - created by @cauerast
# Requires macOS, bash 3.2+, yt-dlp and FFmpeg.
set -uo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
DOWNLOAD_DIR="${HOME}/Downloads"
CYAN=$'\033[36m'
BLUE=$'\033[34m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'
[[ -t 1 ]] || {
  CYAN=''
  BLUE=''
  GREEN=''
  YELLOW=''
  RED=''
  DIM=''
  BOLD=''
  RESET=''
}

center() {
  local message="$1" width cols pad
  width=${#message}
  cols=$(tput cols 2> /dev/null || printf '80')
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  pad=$(((cols - width) / 2))
  ((pad < 0)) && pad=0
  printf '%*s%s\n' "$pad" '' "$message"
}
line() { center '────────────────────────────────────────────────────────────'; }
header() {
  clear 2> /dev/null || true
  printf '\n\n'
  printf '%s' "$CYAN" 
  center '╭────────────────────────────────────────────────────────────╮'
  center '│                            CLIPLY                          │'
  center '│                                                            │'
  center '│                   VIDEO  /  AUDIO  /  4K                   │'
  center '╰────────────────────────────────────────────────────────────╯'
  printf '%s' "$RESET"
  printf '\n'
  printf '%s' "$DIM"
  center 'created by @cauerast  •  macOS edition'
  printf '%s' "$RESET"
  printf '\n'
}
msg() { printf '\n  %b%s%b\n' "$2" "$1" "$RESET"; }
wait_enter() {
  printf '\n  Press ENTER to continue...'
  IFS= read -r _ || true
}
check_dependencies() {
  header
  center 'SYSTEM CHECK'
  line
  if command -v brew > /dev/null 2>&1; then
    for app in yt-dlp ffmpeg; do
      if command -v "$app" > /dev/null 2>&1; then
        msg "[OK] $app detected" "$GREEN"
      else
        msg "[INFO] Installing $app with Homebrew..." "$YELLOW"
        if ! brew install "$app"; then
          msg "[ERROR] Could not install $app. Try: brew install $app" "$RED"
          return 1
        fi
      fi
    done
  else
    if ! command -v yt-dlp > /dev/null 2>&1 || ! command -v ffmpeg > /dev/null 2>&1; then
      msg '[ERROR] Homebrew is not installed.' "$RED"
      printf '  Install Homebrew: https://brew.sh\n  Then run: brew install yt-dlp ffmpeg\n'
      return 1
    fi
    msg '[OK] yt-dlp and FFmpeg detected' "$GREEN"
  fi
  command -v ffprobe > /dev/null 2>&1 || {
    msg '[ERROR] ffprobe is missing (included with FFmpeg).' "$RED"
    return 1
  }
  msg '[READY] All dependencies are available.' "$GREEN"
}
valid_time() { [[ "$1" =~ ^[0-9]+:[0-5][0-9](:[0-5][0-9])?$ ]]; }
seconds() {
  local value="$1" a b c
  IFS=: read -r a b c <<< "$value"
  if [[ -z "${c:-}" ]]; then
    printf '%s' "$((10#$a * 60 + 10#$b))"
  else printf '%s' "$((10#$a * 3600 + 10#$b * 60 + 10#$c))"; fi
}
menu() {
  local url selection playlist_choice cut_start cut_end suffix
  local -a args
  while true; do
    header
    printf '%s' "$BLUE"
    center '01  Video                 MP4 / best available quality'
    center '02  Trim video            MP4 / best available quality'
    center '03  Audio                 MP3 / 320 kbps output'
    center '04  Trim audio            MP3 / 320 kbps output'
    center '05  Audio                 WAV / uncompressed output'
    center '06  Trim audio            WAV / uncompressed output'
    printf '%s' "$RESET"
    printf '\n'
    line
    printf '%s' "$DIM"
    center "Save location: $DOWNLOAD_DIR"
    center 'Press ENTER at the link prompt to exit'
    printf '%s' "$RESET"
    printf '\n  Paste video or playlist URL: '
    IFS= read -r url || break
    [[ -z "$url" ]] && break
    if [[ ! "$url" =~ ^https?:// ]]; then
      msg '[ERROR] Enter an http:// or https:// URL.' "$RED"
      wait_enter
      continue
    fi
    args=(--no-playlist)
    if [[ "$url" == *'list='* || "$url" == *'start_radio='* ]]; then
      printf '\n  Playlist / mix detected. Download [1] current item or [2] entire list? [1]: '
      IFS= read -r playlist_choice || playlist_choice=1
      [[ "$playlist_choice" == 2 ]] && args=(--yes-playlist)
    fi
    printf '\n  Select format: '
    IFS= read -r selection || selection=1
    selection=${selection:-1}
    case "$selection" in 1 | 2 | 3 | 4 | 5 | 6) ;; *)
      msg '[ERROR] Invalid selection.' "$RED"
      wait_enter
      continue
      ;;
    esac
    suffix=''
    if [[ "$selection" == 2 || "$selection" == 4 || "$selection" == 6 ]]; then
      printf '  Start time (MM:SS or HH:MM:SS): '
      IFS= read -r cut_start || cut_start=''
      printf '  End time   (MM:SS or HH:MM:SS): '
      IFS= read -r cut_end || cut_end=''
      if ! valid_time "$cut_start" || ! valid_time "$cut_end"; then
        msg '[ERROR] Use MM:SS or HH:MM:SS.' "$RED"
        wait_enter
        continue
      fi
      if (($(seconds "$cut_start") >= $(seconds "$cut_end"))); then
        msg '[ERROR] End time must be after start time.' "$RED"
        wait_enter
        continue
      fi
      args+=(--download-sections "*$cut_start-$cut_end")
      suffix=' [Trimmed]'
    fi
    args+=(--newline --progress --no-overwrites -P "$DOWNLOAD_DIR")
    case "$selection" in
      1 | 2)
        args+=(-f 'bv*+ba/b' --merge-output-format mp4 --remux-video mp4
          --embed-metadata --embed-chapters
          -o "%(title)s${suffix} [%(resolution)s].%(ext)s")
        ;;
      3 | 4)
        args+=(-f 'bestaudio/best' -x --audio-format mp3 --audio-quality 320K
          --embed-metadata --embed-thumbnail
          -o "%(title)s${suffix} [Audio].%(ext)s")
        ;;
      5 | 6)
        args+=(-f 'bestaudio/best' -x --audio-format wav
          --embed-metadata
          -o "%(title)s${suffix} [Audio].%(ext)s")
        ;;
    esac
    printf '\n'
    line
    msg 'Downloading...' "$CYAN"
    if yt-dlp "${args[@]}" -- "$url"; then
      msg '[SUCCESS] Finished. Check your Downloads folder.' "$GREEN"
    else
      msg '[ERROR] Download failed. See output above.' "$RED"
      printf '  Try: brew upgrade yt-dlp ffmpeg\n'
    fi
    wait_enter
  done
}

trap 'printf "\n"; exit 130' INT
if check_dependencies; then
  wait_enter
  menu
else
  wait_enter
  exit 1
fi
printf '\n  Thanks for using CLIPLY <3 !\n'
