#!/usr/bin/env bash
# CLIPLY — created by @cauerast
# macOS / Bash 3.2+ / yt-dlp / FFmpeg
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
  pad=$(( (cols - ${#message}) / 2 )); (( pad < 0 )) && pad=0
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

check_dependencies() {
  local missing='' app
  for app in yt-dlp ffmpeg ffprobe; do
    command -v "$app" >/dev/null 2>&1 || missing="$missing $app"
  done
  [[ -z "$missing" ]] && return 0
  header
  msg "Missing dependencies:$missing" "$YELLOW"
  if command -v brew >/dev/null 2>&1; then
    printf '\n  Install them with: brew install yt-dlp ffmpeg\n'
  else
    printf '\n  Install Homebrew (https://brew.sh), then run:\n  brew install yt-dlp ffmpeg\n'
  fi
  return 1
}

valid_time() { [[ "$1" =~ ^[0-9]+:[0-5][0-9](:[0-5][0-9])?$ ]]; }
seconds() {
  local a b c
  IFS=: read -r a b c <<< "$1"
  a=$((10#$a)); b=$((10#$b))
  if [[ -z "${c:-}" ]]; then printf '%s' "$((a * 60 + b))"
  else c=$((10#$c)); printf '%s' "$((a * 3600 + b * 60 + c))"; fi
}
read_choice() {
  local key
  if [[ -t 0 ]]; then IFS= read -r -s -n 1 key || return 1
  else IFS= read -r key || return 1; fi
  printf '%s\n' "${key:-1}"
}

# Each request is isolated. Nothing is moved to Downloads until yt-dlp succeeds.
STAGE=''; JOB_PID=''; LOG_FILE=''; CANCELLED=0
cleanup_stage() {
  if [[ -n "$STAGE" && -d "$STAGE" ]]; then rm -rf -- "$STAGE"; fi
  STAGE=''; LOG_FILE=''
}
kill_tree() {
  local parent="$1" child
  # Stop ffmpeg and other subprocesses before stopping yt-dlp.
  for child in $(pgrep -P "$parent" 2>/dev/null || true); do kill_tree "$child"; done
  kill -TERM "$parent" 2>/dev/null || true
}
interrupt() {
  if [[ -n "$JOB_PID" ]]; then kill_tree "$JOB_PID"; wait "$JOB_PID" 2>/dev/null || true; fi
  cleanup_stage
  printf '\n'
  exit 130
}
trap interrupt INT TERM
trap cleanup_stage EXIT

render_progress() {
  local percent="$1" tick="$2" width=30 fill i bar='' label
  if [[ "$percent" =~ ^[0-9]+$ ]]; then
    (( percent > 100 )) && percent=100
    (( percent < 0 )) && percent=0
    fill=$((percent * width / 100))
    for ((i=0; i<width; i++)); do
      if ((i < fill)); then bar+='━'; else bar+='─'; fi
    done
    label=$(printf '%3d%%' "$percent")
  else
    # Unknown duration, common with ffmpeg-backed trims/postprocessing.
    fill=$((tick % width))
    for ((i=0; i<width; i++)); do
      if ((i == fill)); then bar+='●'; else bar+='─'; fi
    done
    label=' --%'
  fi
  printf '\r\033[2K  %b%s%b  [%s]  %s' "$CYAN" "$label" "$RESET" "$bar" "$3"
}

# Starts yt-dlp in background and draws ONE progress line; never prints its raw logs.
run_download() {
  local url="$1"; shift
  local -a args=("$@")
  local tick=0 pct='' newpct='' activity='Downloading' key='' status=0
  STAGE=$(mktemp -d "$DOWNLOAD_DIR/.cliply.XXXXXXXX") || return 1
  LOG_FILE="$STAGE/progress.log"

  # --newline is only written to a private log, never to the terminal.
  # No bogus % during postprocessing; completion is 100% only after success.
  yt-dlp --quiet --no-warnings --progress --newline --no-colors \
    --progress-template 'download:CLIPLY_PROGRESS %(progress._percent_str)s' \
    --no-overwrites -P "$STAGE" "${args[@]}" -- "$url" >"$LOG_FILE" 2>&1 &
  JOB_PID=$!

  printf '\n  %bPress q to cancel and discard this download.%b\n\n' "$DIM" "$RESET"
  render_progress '' 0 'Preparing...'
  while kill -0 "$JOB_PID" 2>/dev/null; do
    # Percent is meaningful only for the *current* stream. The bar can restart
    # for the audio stream after video, or for each playlist item.
    newpct=$(grep 'CLIPLY_PROGRESS' "$LOG_FILE" 2>/dev/null | tail -n 1 | sed -E 's/.*CLIPLY_PROGRESS[[:space:]]+([0-9]+([.][0-9]+)?)%.*/\1/' || true)
    if [[ "$newpct" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      pct=${newpct%%.*}
      if (( pct >= 100 )); then activity='Processing...'
      else activity='Downloading'; fi
    else
      pct=''
      activity='Working'
    fi
    render_progress "$pct" "$tick" "$activity"
    tick=$((tick + 1))

    if [[ -t 0 ]]; then
      # Bash's timed one-character read temporarily handles terminal input.
      key=''
      IFS= read -r -s -n 1 -t 1 key </dev/tty || true
      if [[ "$key" == 'q' || "$key" == 'Q' ]]; then
        CANCELLED=1
        kill_tree "$JOB_PID"
        wait "$JOB_PID" 2>/dev/null || true
        JOB_PID=''
        printf '\n'
        cleanup_stage
        msg '[CANCELLED] Temporary files discarded.' "$YELLOW"
        return 2
      fi
    else
      sleep 1
    fi
  done

  wait "$JOB_PID" || status=$?
  JOB_PID=''
  if (( status != 0 )); then
    printf '\n'
    msg '[ERROR] Download or conversion failed.' "$RED"
    printf '  Last error details:\n'
    tail -n 8 "$LOG_FILE" | sed 's/^/  /'
    cleanup_stage
    return 1
  fi

  # Publish only completed files. No partially downloaded files in Downloads.
  local file name moved=0
  while IFS= read -r -d '' file; do
    name=${file##*/}
    case "$name" in progress.log|*.part|*.ytdl|*.temp) continue ;; esac
    if [[ -e "$DOWNLOAD_DIR/$name" ]]; then
      printf '\n  [SKIPPED] Already exists: %s\n' "$name"
    elif mv -n "$file" "$DOWNLOAD_DIR/$name"; then
      moved=$((moved + 1))
    else
      printf '\n  [ERROR] Could not move: %s\n' "$name"
      status=1
    fi
  done < <(find "$STAGE" -type f -print0)
  render_progress 100 0 'Complete'
  printf '\n'
  cleanup_stage
  (( status == 0 ))
}

menu() {
  local url selection playlist_choice cut_start cut_end suffix result
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
      wait_enter; continue
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
      if ! valid_time "$cut_start" || ! valid_time "$cut_end" || (( $(seconds "$cut_start") >= $(seconds "$cut_end") )); then
        msg '[ERROR] Invalid time range.' "$RED"; wait_enter; continue
      fi
      args+=(--download-sections "*$cut_start-$cut_end")
      suffix=' [Trimmed]'
    fi
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
    printf '\n'; line
    result=0
    run_download "$url" "${args[@]}" || result=$?
    if (( result == 0 )); then msg '[SUCCESS] Finished. Check your Downloads folder.' "$GREEN"
    elif (( result != 2 )); then msg '[ERROR] See error details above.' "$RED"; fi
    wait_enter
  done
}

mkdir -p "$DOWNLOAD_DIR" || exit 1
if check_dependencies; then menu
else wait_enter; exit 1; fi
printf '\n  Thanks for using CLIPLY <3 !\n'
