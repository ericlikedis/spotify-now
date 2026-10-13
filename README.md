# spotify-now

An oh-my-zsh plugin that shows the track Spotify is playing in your prompt, in a
green box with animated equalizer bars. macOS only.

```
 ⣤⣶ ♪ Artist - Title
```

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

## Notes

- Tested with zsh 5.9 on macOS and iTerm2. Powerlevel10k needs a custom segment
  instead of `RPROMPT`.
- Not affiliated with Spotify. It uses the app's local scripting interface and
  not the Web API.
