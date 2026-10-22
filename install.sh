#!/usr/bin/env bash
# CLIPLY installer for macOS — created by @cauerast
# Installs the CLI and a Finder-launchable .command file.
set -euo pipefail

REPOSITORY="https://raw.githubusercontent.com/cauerast/cliply/main"
APP_DIR="$HOME/.local/share/cliply"
BIN_DIR="$HOME/.local/bin"
LAUNCHER_DIR="$HOME/Applications"

info() { printf '\033[36m[CLIPLY]\033[0m %s\n' "$*"; }
fail() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail 'This installer supports macOS only.'
command -v curl >/dev/null 2>&1 || fail 'curl is required.'

# Resolve Homebrew on both Apple Silicon and Intel Macs, including shortcuts.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if ! command -v brew >/dev/null 2>&1; then
  fail 'Homebrew is required. Install it from https://brew.sh/ and rerun this command.'
fi

info 'Checking dependencies...'
for dependency in yt-dlp ffmpeg; do
  if command -v "$dependency" >/dev/null 2>&1; then
    info "$dependency is already installed."
  else
    info "Installing $dependency using Homebrew..."
    brew install "$dependency" || fail "Could not install $dependency."
  fi
done
command -v ffprobe >/dev/null 2>&1 || fail 'ffprobe is missing; reinstall FFmpeg with Homebrew.'

info 'Downloading Cliply...'
mkdir -p "$APP_DIR" "$BIN_DIR" "$LAUNCHER_DIR"
TEMP_FILE="$(mktemp "$APP_DIR/.cliply.XXXXXX")"
trap 'rm -f "$TEMP_FILE"' EXIT
curl --fail --location --show-error --silent \
  "$REPOSITORY/macos/cliply.sh" --output "$TEMP_FILE" \
  || fail 'Could not download macos/cliply.sh. Confirm the repository is public and the path exists.'
[[ -s "$TEMP_FILE" ]] || fail 'Downloaded file is empty.'
/bin/bash -n "$TEMP_FILE" || fail 'Downloaded script did not pass Bash syntax checking.'
chmod 755 "$TEMP_FILE"
mv -f "$TEMP_FILE" "$APP_DIR/cliply.sh"

# CLI executable, so `cliply` invokes the installed script.
cat > "$BIN_DIR/cliply" <<'WRAPPER'
#!/usr/bin/env bash
exec /bin/bash "$HOME/.local/share/cliply/cliply.sh" "$@"
WRAPPER
chmod 755 "$BIN_DIR/cliply"

# Finder opens .command files in Terminal; no Shortcuts setup required.
cat > "$LAUNCHER_DIR/Cliply.command" <<'LAUNCHER'
#!/usr/bin/env bash
exec /bin/bash "$HOME/.local/share/cliply/cliply.sh"
LAUNCHER
chmod 755 "$LAUNCHER_DIR/Cliply.command"

# Enable the CLI in new zsh login shells (macOS default).
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  PROFILE="$HOME/.zprofile"
  PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
  if ! grep -Fqx "$PATH_LINE" "$PROFILE" 2>/dev/null; then
    printf '\n# Cliply CLI\n%s\n' "$PATH_LINE" >> "$PROFILE"
    info 'Added ~/.local/bin to ~/.zprofile (takes effect in new Terminal windows).'
  fi
fi

printf '\n'
info 'Installation complete!'
printf '  CLI:       %s\n' "$BIN_DIR/cliply"
printf '  Launcher:  %s\n' "$LAUNCHER_DIR/Cliply.command"
printf '\nOpen a new Terminal window and type: cliply\n'
printf 'Or double-click ~/Applications/Cliply.command in Finder.\n'
printf 'To update Cliply later, rerun the installer.\n'
