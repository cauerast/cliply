#!/usr/bin/env bash
# CLIPLY — created by @cauerast
# macOS, Bash 3.2+, yt-dlp, FFmpeg
set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
DOWNLOAD_DIR="$HOME/Downloads"
CYAN=$'\033[36m'; BLUE=$'\033[34m'; GREEN=$'\033[32m'
YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
[[ -t 1 ]] || { CYAN=''; BLUE=''; GREEN=''; YELLOW=''; RED=''; DIM=''; RESET=''; }

center() {
  local message="$1" cols pad
  cols=$(tput cols 2>/dev/null || printf '80')
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  pad=$(( (cols - ${#message}) / 2 ))
  (( pad < 0 )) && pad=0
  printf '%*s%s\n' "$pad" '' "$message"
}
line() { center '────────────────────────────────────────────────────────────'; }
header() {
  clear 2>/dev/null || true
  printf '\n\n%s' "$CYAN"
  center '╭────────────────────────────────────────────────────────────╮'
  center '│                            CLIPLY                          │'
  center '│                                                            │'
  center '│                   VIDEO  /  AUDIO  /  4K                   │'
  center '╰────────────────────────────────────────────────────────────╯'
  printf '%s\n%s' "$RESET" "$DIM"
  center 'created by @cauerast  •  macOS edition'
  printf '%s\n' "$RESET"
}
msg() { printf '\n  %b%s%b\n' "$2" "$1" "$RESET"; }
wait_enter() { printf '\n  Press ENTER to continue...'; IFS= read -r _ || true; }

# No messages and no pause when dependencies are present.
check_dependencies() {
  local missing='' app
  for app in yt-dlp ffmpeg ffprobe; do
    command -v "$app" >/dev/null 2>&1 || missing="$missing $app"
  done
  [[ -z "$missing" ]] && return 0

  header
  msg "Missing dependencies:$missing" "$YELLOW"
  if ! command -v brew >/dev/null 2>&1; then
    msg 'Homebrew is required to install missing tools: https://brew.sh' "$RED"
    printf '  After installing Homebrew, run: brew install yt-dlp ffmpeg\n'
    return 1
  fi
  printf '  Install missing dependencies with:\n  brew install yt-dlp ffmpeg\n'
  printf '\n  After installation, run cliply again.\n'
  return 1
}

valid_time() { [[ "$1" =~ ^[0-9]+:[0-5][0-9](:[0-5][0-9])?$ ]]; }
seconds() {
  local a b c
  IFS=: read -r a b c <<< "$1"
  # Prefix with 1 and subtract a power of 10: avoids octal interpretation of 08/09.
  if [[ -z "${c:-}" ]]; then
    printf '%s' "$(( (1$a - 10**${#a}) * 60 + (1$b - 10**${#b}) ))"
  else
    printf '%s' "$(( (1$a - 10**${#a}) * 3600 + (1$b - 10**${#b}) * 60 + (1$c - 10**${#c}) ))"
  fi
}

# One key selection (macOS system Bash 3.2 supports read -s -n 1).
read_choice() {
  local key
  if [[ -t 0 ]]; then
    IFS= read -r -s -n 1 key || return 1
    printf '%s\n' "${key:-1}"
  else
    IFS= read -r key || return 1
    printf '%s\n' "${key:-1}"
  fi
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
    printf '%s\n' "$RESET"
    line
    printf '%s' "$DIM"
    center "Save location: $DOWNLOAD_DIR"
    center 'Press ENTER at the link prompt to exit'
    printf '%s\n' "$RESET"

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
      printf '\n  Playlist / mix detected. [1] Current item / [2] Entire list [1]: '
      playlist_choice=$(read_choice) || break
      printf '%s\n' "$playlist_choice"
      [[ "$playlist_choice" == 2 ]] && args=(--yes-playlist)
    fi
    printf '\n  Select format: '
    selection=$(read_choice) || break
    printf '%s\n' "$selection"
    case "$selection" in
      1|2|3|4|5|6) ;;
      *) msg '[ERROR] Invalid selection.' "$RED"; wait_enter; continue ;;
    esac
    suffix=''
    if [[ "$selection" == 2 || "$selection" == 4 || "$selection" == 6 ]]; then
      printf '  Start time (MM:SS or HH:MM:SS): '
      IFS= read -r cut_start || break
      printf '  End time   (MM:SS or HH:MM:SS): '
      IFS= read -r cut_end || break
      if ! valid_time "$cut_start" || ! valid_time "$cut_end"; then
        msg '[ERROR] Use MM:SS or HH:MM:SS.' "$RED"
        wait_enter
        continue
      fi
      if (( $(seconds "$cut_start") >= $(seconds "$cut_end") )); then
        msg '[ERROR] End time must be after start time.' "$RED"
        wait_enter
        continue
      fi
      args+=(--download-sections "*$cut_start-$cut_end")
      suffix=' [Trimmed]'
    fi
    # yt-dlp uses one updating terminal line by default; --newline caused one line per update.
    args+=(--progress --no-overwrites -P "$DOWNLOAD_DIR")
    case "$selection" in
      1|2)
        args+=(-f 'bv*+ba/b' --merge-output-format mp4 --remux-video mp4
          --embed-metadata --embed-chapters
          -o "%(title)s${suffix} [%(resolution)s].%(ext)s") ;;
      3|4)
        args+=(-f 'bestaudio/best' -x --audio-format mp3 --audio-quality 320K
          --embed-metadata --embed-thumbnail
          -o "%(title)s${suffix} [Audio].%(ext)s") ;;
      5|6)
        args+=(-f 'bestaudio/best' -x --audio-format wav --embed-metadata
          -o "%(title)s${suffix} [Audio].%(ext)s") ;;
    esac
    printf '\n'; line; msg 'Downloading...' "$CYAN"
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
  menu
else
  wait_enter
  exit 1
fi
printf '\n  Thanks for using CLIPLY <3 !\n'
