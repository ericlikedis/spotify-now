# spotify-now

An oh-my-zsh plugin that shows the track Spotify is playing in your prompt, in a
green box with animated equalizer bars. Works on macOS and Linux.

```
 ⣤⣶ ♪ Artist - Title
```

<img width="738" height="440" alt="iTerm2-2026-10-13-18-51" src="https://github.com/user-attachments/assets/93eb2970-e689-4135-848c-014b8a98d8ce" />


## How it works

- Asks the Spotify desktop app what is playing, in a background job so typing
  never lags. On macOS it uses AppleScript (`osascript`). On Linux it reads the
  MPRIS D-Bus interface with `busctl` (part of systemd), parsed with `jq`
  (or `python3` if `jq` is missing). Spotify installed from Flatpak works.
- A background ticker drives the animation through `zle -F`. No signals or
  `TMOUT` traps are used.
- The bars are decorative. Spotify does not expose audio levels.

## Install (macOS)

```zsh
git clone https://github.com/ericlikedis/spotify-now.git ~/.oh-my-zsh/custom/plugins/spotify-now
```

In `~/.zshrc`:

```zsh
plugins=(... spotify-now)    # before zsh-syntax-highlighting, which should stay last

source $ZSH/oh-my-zsh.sh

setopt PROMPT_SUBST
RPROMPT='$SPOTIFY_SEGMENT'
```

On macOS, the first time it runs, macOS asks whether your terminal may control
Spotify. Allow it. On Linux nothing extra is needed.

## Install on Arch Linux and SteamOS

Everything below lives in your home directory, so it survives reboots and
SteamOS system updates. You never need `pacman` or to unlock the read-only root
on SteamOS.

### 1. Requirements

| Need | SteamOS | Arch |
|---|---|---|
| `zsh` | Preinstalled | `sudo pacman -S zsh` |
| `git`, `curl` | Preinstalled | `sudo pacman -S git curl` |
| `busctl` | Preinstalled (part of systemd) | Preinstalled (part of systemd) |
| `jq` (or `python3` as a fallback) | Preinstalled | `sudo pacman -S jq` |
| Spotify desktop app | Flatpak (below) | Flatpak, or the AUR `spotify` package |

Check what you have:

```zsh
for c in zsh git curl busctl jq; do command -v $c >/dev/null && echo "ok  $c" || echo "MISSING  $c"; done
```

### 2. Spotify

On SteamOS, open Desktop Mode, then Discover, and install **Spotify**. Or from
a terminal:

```zsh
flatpak install flathub com.spotify.Client
```

Start Spotify and play something. The plugin only reads what is playing; it
needs no login or API key. It talks to Spotify's MPRIS D-Bus name
(`org.mpris.MediaPlayer2.spotify`), which the Flatpak exposes by default.

### 3. oh-my-zsh

Skip this if `~/.oh-my-zsh` already exists.

```zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### 4. The plugin

```zsh
git clone https://github.com/ericlikedis/spotify-now.git ~/.oh-my-zsh/custom/plugins/spotify-now
```

Add it to `~/.zshrc`. Keep `zsh-syntax-highlighting` last if you use it:

```zsh
plugins=(git spotify-now)

source $ZSH/oh-my-zsh.sh

setopt PROMPT_SUBST
RPROMPT='$SPOTIFY_SEGMENT'
```

The `RPROMPT` and `setopt` lines must come after the `source` line.

### 5. Make your terminal use zsh

Open a new terminal. If the prompt looks unchanged, your terminal is probably
starting bash. Either:

- **Konsole** (SteamOS Desktop Mode): Settings, Edit Current Profile, set
  **Command** to `/usr/bin/zsh`. This needs no password and survives updates.
- **Or** change your login shell: `chsh -s /usr/bin/zsh`. This needs your
  password, so set one first with `passwd` on a stock Steam Deck.

### 6. Check it works

With Spotify playing, a green box should appear on the right of your prompt
within about 5 seconds. To test the lookup on its own, without the prompt:

```zsh
busctl --user --json=short get-property org.mpris.MediaPlayer2.spotify \
  /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player PlaybackStatus
```

You should see `{"type":"s","data":"Playing"}`.

### Troubleshooting

| Symptom | Fix |
|---|---|
| Nothing appears | Make sure a track is **playing**, not paused. Nothing is shown when paused or when Spotify is closed |
| `The name is not activatable` | Spotify is not running, or not exposing MPRIS. Run `busctl --user list \| grep -i mpris` while it plays. If nothing shows up, restart Spotify |
| Works in one terminal, not another | That terminal is starting bash. See step 5 |
| Box has odd symbols at the ends | You lack a Nerd Font. Add `SPOTIFY_ROUNDED=0` to `~/.zshrc` above the `source` line |
| Wrong colors | Use a truecolor terminal (Konsole is). Check `echo $COLORTERM` prints `truecolor` |
| `spotify-now-color` prints a URL instead of opening a browser | `xdg-open` is missing. Open the printed URL yourself |

Only the SteamOS and Flatpak Spotify setup has been tested. Arch with the AUR
package should work the same way, since MPRIS is the same, but has not been
verified.

## Options

Set these before `source $ZSH/oh-my-zsh.sh`.

| Variable | Default | Meaning |
|---|---|---|
| `SPOTIFY_ROUNDED` | `1` | Rounded caps. Needs a Nerd Font; set `0` for a square box |
| `SPOTIFY_BARS_INTERVAL` | `0.12` | Seconds between animation frames |
| `SPOTIFY_NOW_INTERVAL` | `5` | Seconds between track checks |
| `SPOTIFY_TRANSIENT` | `1` | Only show the segment on the line you're typing on. Sets zsh's global `transient_rprompt` option, so it applies to anything in `RPROMPT`. Set `0` to keep it on earlier lines |
| `SPOTIFY_COLOR` | unset | Box color as `#RRGGBB`. Overrides a color saved with `spotify-now-color` |

## Choosing a color

<img width="800" height="272" alt="iTerm2-2026-10-13-18-25" src="https://github.com/user-attachments/assets/e33bafb3-5852-48c1-9461-8dac91fef690" />


```zsh
spotify-now-color            # opens color-picker.html in your browser
spotify-now-color '#ff5f87'  # set and save a color directly
spotify-now-color reset      # back to Spotify green
```

The picker page has a color wheel, a hex field, a live preview and a "Copy"
button. It generates the `spotify-now-color '#rrggbb'` command; paste it into a
terminal and the new color applies on the next prompt redraw. Your choice is
saved to `~/.config/spotify-now/color` (or `$XDG_CONFIG_HOME/spotify-now/color`).

Text color switches between black and white automatically, based on how bright
the box color is. Colors are validated as `#RRGGBB` before being used, and
anything else is rejected.

Hex colors need a truecolor terminal (iTerm2 and Terminal.app on recent macOS
qualify). Elsewhere, zsh approximates them with its 256-color palette.

## Notes

- Tested with zsh 5.9 on macOS and iTerm2, and on SteamOS (Arch) with the Flatpak Spotify. Powerlevel10k needs a custom segment
  instead of `RPROMPT`.
- Not affiliated with Spotify. It uses the app's local scripting interface and
  not the Web API.
