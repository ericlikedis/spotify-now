# spotify-now

An oh-my-zsh plugin that shows the track Spotify is playing in your prompt, in a
green box with animated equalizer bars. macOS only.

```
 ⣤⣶ ♪ Artist - Title
```

<img width="738" height="440" alt="iTerm2-2026-10-13-18-51" src="https://github.com/user-attachments/assets/93eb2970-e689-4135-848c-014b8a98d8ce" />


## How it works

- Asks the Spotify desktop app what is playing through AppleScript (`osascript`),
  in a background job so typing never lags.
- A background ticker drives the animation through `zle -F`. No signals or
  `TMOUT` traps are used.
- The bars are decorative. Spotify does not expose audio levels.

## Install

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

The first time it runs, macOS asks whether your terminal may control Spotify.
Allow it.

## Options

Set these before `source $ZSH/oh-my-zsh.sh`.

| Variable | Default | Meaning |
|---|---|---|
| `SPOTIFY_ROUNDED` | `1` | Rounded caps. Needs a Nerd Font; set `0` for a square box |
| `SPOTIFY_BARS_INTERVAL` | `0.12` | Seconds between animation frames |
| `SPOTIFY_NOW_INTERVAL` | `5` | Seconds between track checks |
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

- Tested with zsh 5.9 on macOS and iTerm2. Powerlevel10k needs a custom segment
  instead of `RPROMPT`.
- Not affiliated with Spotify. It uses the app's local scripting interface and
  not the Web API.
