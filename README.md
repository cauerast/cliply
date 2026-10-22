<div align="center">

# CLIPLY

**A clean, terminal-first video & audio downloader for Windows and macOS.**

`MP4` · `MP3 320K` · `WAV` · `TRIMMING` · `PLAYLISTS` · `4K WHEN AVAILABLE`

**Created by [@cauerast](https://github.com/cauerast)**

</div>

---

## About

CLIPLY is an interactive wrapper around [yt-dlp](https://github.com/yt-dlp/yt-dlp) and [FFmpeg](https://ffmpeg.org/). Paste a supported media URL, select a format, and find the result in your **Downloads** folder. Windows and macOS share six modes, a terminal menu, dependency checks, and a playlist prompt.

> **Respect creators and platform rules.** CLIPLY does not bypass DRM or guarantee access to restricted content.

## Preview

```text
          ╭────────────────────────────────────────────────────────────╮
          │                            CLIPLY                          │
          │                   VIDEO  /  AUDIO  /  4K                   │
          ╰────────────────────────────────────────────────────────────╯

                       created by @cauerast

          01  Video                 MP4 / best available quality
          02  Trim video            MP4 / best available quality
          03  Audio                 MP3 / 320 kbps output
          04  Trim audio            MP3 / 320 kbps output
          05  Audio                 WAV / uncompressed output
          06  Trim audio            WAV / uncompressed output
```

## Features

- Six download modes: full video, trimmed video, full/trimmed MP3, and full/trimmed WAV.
- Best available source quality, including 4K where supported by the source and yt-dlp.
- MP4 merge/remux when compatible; optional metadata and thumbnail embedding.
- Time ranges in `MM:SS` or `HH:MM:SS`.
- Playlist/mix recognition with a prompt for one item or the full list.
- Downloads to `~/Downloads` (macOS) or `%USERPROFILE%\Downloads` (Windows).
- Local interface; yt-dlp accesses the selected online source.

## Repository structure

```text
cliply/
├── install.sh                  # One-command macOS installer
├── README.md
├── LICENSE
├── windows/
│   └── cliply.bat
└── macos/
    ├── cliply.sh
    └── Launch cliply.command  # Optional standalone launcher
```

## macOS — quick installation (recommended)

**Requirements:** macOS (Apple Silicon or Intel), [Homebrew](https://brew.sh/), and internet access.

With Homebrew installed, open **Terminal** and run 2 times (1 - install; 2 - update):

```bash
curl -fsSL https://raw.githubusercontent.com/cauerast/cliply/main/install.sh | bash
```

The installer:

1. Checks for Homebrew (shows a link to install it if absent).
2. Installs `yt-dlp` and `ffmpeg` through Homebrew **only if they are missing**.
3. Downloads `macos/cliply.sh` from this repository into `~/.local/share/cliply/`.
4. Creates the `cliply` command in `~/.local/bin/`.
5. Creates `~/Applications/Cliply.command` to launch Cliply by double-clicking in Finder.
6. Adds `~/.local/bin` to `~/.zprofile` if needed for new Terminal windows.

**Launch:** open a **new Terminal window** and type:

```bash
cliply
```

Or, in Finder, select **Go → Go to Folder...**, enter `~/Applications`, and double-click **Cliply.command**. This launches an interactive Terminal session with the menu. You may drag the launcher to a convenient location or create a macOS Shortcut for it.

**Update CLIPLY:** run the same installer again. To update the underlying tools separately:

```bash
brew update && brew upgrade yt-dlp ffmpeg
```

### macOS — manual installation

You can use CLIPLY without the one-command installer:

```bash
git clone https://github.com/cauerast/cliply.git
cd cliply
brew install yt-dlp ffmpeg
bash macos/cliply.sh
```

To use the bundled Finder launcher, restore execute permissions if needed:

```bash
chmod +x "macos/Launch cliply.command" macos/cliply.sh
```

Then double-click `macos/Launch cliply.command`.

### macOS — create an Apple Shortcut

**If you used the quick installer**, you do not need to clone the repository or choose a permanent source path.

1. Open **Shortcuts** and create a shortcut called **Cliply**.
2. Add **Run Shell Script** (if your Shortcuts version provides it).
3. Paste this into the action:

   ```bash
   SCRIPT="$HOME/.local/share/cliply/cliply.sh"
   osascript - "$SCRIPT" <<'APPLESCRIPT'
   on run argv
       set scriptPath to item 1 of argv
       tell application "Terminal"
           activate
           do script "bash " & quoted form of scriptPath
       end tell
   end run
   APPLESCRIPT
   ```

4. Run the shortcut and allow it to control Terminal if macOS prompts you.
5. Optionally pin it to the menu bar, assign a keyboard shortcut, or add it to the Dock if available.

> Pasting the entire `cliply.sh` into the **Run Shell Script** action is **not recommended**: its interactive prompts require a real Terminal window. The AppleScript above opens Terminal and runs the installed program.

**If you installed manually**, replace the `SCRIPT=...` path with the location of `macos/cliply.sh` on your Mac.

### macOS troubleshooting

- **`brew: command not found`** — install Homebrew from [brew.sh](https://brew.sh/) and rerun the installer.
- **`cliply: command not found`** — open a new Terminal window, or run `source ~/.zprofile`; alternatively use `~/.local/bin/cliply`.
- **Shortcut cannot control Terminal** — check the macOS automation permission prompt / settings.
- **Launcher won't open** — verify the file exists at `~/Applications/Cliply.command`; run `chmod +x ~/Applications/Cliply.command` and follow macOS security prompts.
- **File not found during installation** — confirm the repo is public, the default branch is `main`, and `macos/cliply.sh` exists in that branch.

## Windows 10 / 11

1. Download the repository ZIP or clone the repo.
2. Double-click `windows/cliply.bat` (or launch it in Command Prompt).
3. CLIPLY checks for `yt-dlp`, `ffmpeg`, and `ffprobe`. If tools are missing, it uses **WinGet** to install them when possible.
4. If dependencies were freshly installed, you may need to close and reopen the terminal before launching again.

**Manual dependencies** (PowerShell or Windows Terminal):

```powershell
winget install --id yt-dlp.yt-dlp -e
winget install --id Gyan.FFmpeg -e
```

If WinGet is missing, install Microsoft's **App Installer** first.

**Desktop shortcut:** right-click `windows/cliply.bat` → **Show more options** → **Send to** → **Desktop (create shortcut)**, where supported by your Windows version.

**Update dependencies:**

```powershell
winget upgrade --id yt-dlp.yt-dlp -e
winget upgrade --id Gyan.FFmpeg -e
```

## Usage

1. Launch CLIPLY through the macOS CLI, Finder launcher, Shortcut, or Windows `.bat`.
2. Paste a supported media URL.
3. If the link contains a playlist/mix, choose the single item or entire list.
4. Select a format from `1` to `6` (ENTER defaults to video).
5. For trimmed modes, enter start/end times (for example, `00:30` and `01:45`).
6. Follow progress in Terminal, then find the file in **Downloads**.

## Quality notes

- **4K isn't guaranteed.** Available formats depend on the source and yt-dlp extraction support.
- **WAV output is uncompressed, but not necessarily lossless relative to the original recording.** It cannot restore data discarded by a lossy source.
- **320 kbps describes the MP3 output encoding**, not the source's original fidelity.
- **MP4 remuxing doesn't necessarily re-encode**, so compatibility depends on codecs.
- **Trim boundaries may be approximate** for some media; FFmpeg is required.
- **Download speed varies** with the source, format, connection, and processing.

## Credits

Created by **[@cauerast](https://github.com/cauerast)**. Powered by [yt-dlp](https://github.com/yt-dlp/yt-dlp) and [FFmpeg](https://ffmpeg.org/).

## License

MIT — see [LICENSE](LICENSE).
