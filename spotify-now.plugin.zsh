# spotify-now: Spotify now-playing segment with animated equalizer bars (macOS and Linux).
#
# No signals: a background ticker writes one line per frame to a pipe and zle
# calls _spotify_on_tick (via `zle -F`) when it is readable, at a safe point
# inside zle.
#
# Add $SPOTIFY_SEGMENT to your prompt, e.g.:
#   setopt PROMPT_SUBST
#   RPROMPT='$SPOTIFY_SEGMENT'

SPOTIFY_NOW=""
SPOTIFY_BARS="⣤⣶"
SPOTIFY_SEGMENT=""
typeset -ga _spotify_heights=(2 3 4 2)   # bar heights, 1-4
typeset -gi _spotify_frame=0
_spotify_fd=""
_spotify_cache="${TMPDIR:-/tmp}/spotify-now.$UID"
: ${SPOTIFY_BARS_INTERVAL:=0.12}    # seconds between bar animation frames
: ${SPOTIFY_NOW_INTERVAL:=0.2}      # seconds between track refreshes
: ${SPOTIFY_ROUNDED:=1}             # 1 = rounded caps (needs a Nerd Font), 0 = square box
: ${SPOTIFY_TRANSIENT:=1}           # 1 = only show on the active line (when used in RPROMPT)

# Clears the right prompt from earlier lines once you press Enter. This is a
# global zsh option, so it also applies to anything else you put in RPROMPT.
(( SPOTIFY_TRANSIENT )) && setopt transient_rprompt
# Box color as #RRGGBB. Set it here, or pick one with `spotify-now-color`.
# Precedence: SPOTIFY_COLOR from your .zshrc, else the saved choice, else green.

_spotify_dir=${0:A:h}
_spotify_color_file="${XDG_CONFIG_HOME:-$HOME/.config}/spotify-now/color"

zmodload zsh/zselect 2>/dev/null    # fork-free sub-second waits
# Hex colors need truecolor; otherwise let zsh approximate them in 256 colors.
[[ $COLORTERM == (truecolor|24bit) ]] || zmodload zsh/nearcolor 2>/dev/null

# Validate a color; prints it as lowercase #rrggbb, fails on anything else.
# Callers must use this before the value reaches a prompt string.
_spotify_normalize_color() {
  [[ $1 =~ '^#?([0-9a-fA-F]{6})$' ]] || return 1
  print -r -- "#${(L)match[1]}"
}

# Set the box colors from a validated #rrggbb: background, readable text, caps
_spotify_apply_color() {
  local hex=$1
  local -i r=$(( 16#${hex[2,3]} )) g=$(( 16#${hex[4,5]} )) b=$(( 16#${hex[6,7]} ))
  _spotify_bg=$hex
  # perceived brightness decides black or white text
  if (( (r * 299 + g * 587 + b * 114) / 1000 > 100 )); then
    _spotify_fg="#000000"
  else
    _spotify_fg="#ffffff"
  fi
}

# spotify-now-color            open the HTML color picker
# spotify-now-color '#1db954'  set and save a color
# spotify-now-color reset      go back to Spotify green
spotify-now-color() {
  local arg=$1 hex
  case $arg in
    ""|pick)
      local url="file://${_spotify_dir// /%20}/color-picker.html#${_spotify_bg#\#}"
      if (( $+commands[open] )); then
        open "$url"
      elif (( $+commands[xdg-open] )); then
        xdg-open "$url" >/dev/null 2>&1
      else
        print -r -- "Open this in a browser: $url"
      fi
      ;;
    reset)
      rm -f -- "$_spotify_color_file"
      _spotify_apply_color "#1db954"
      _spotify_build_segment
      print -r -- "spotify-now: color reset to #1db954"
      ;;
    *)
      if ! hex=$(_spotify_normalize_color "$arg"); then
        print -u2 -r -- "spotify-now: '$arg' is not a #RRGGBB color"
        return 1
      fi
      mkdir -p -- "${_spotify_color_file:h}" && print -r -- "$hex" > "$_spotify_color_file"
      _spotify_apply_color "$hex"
      _spotify_build_segment
      print -r -- "spotify-now: color set to $hex"
      ;;
  esac
}

# Pick the starting color
() {
  local hex
  if [[ -n $SPOTIFY_COLOR ]]; then
    hex=$(_spotify_normalize_color "$SPOTIFY_COLOR")
  elif [[ -r $_spotify_color_file ]]; then
    hex=$(_spotify_normalize_color "$(<$_spotify_color_file)")
  fi
  _spotify_apply_color "${hex:-#1db954}"
}

# Linux: ask Spotify over MPRIS (D-Bus). Prints "Artist - Title" while playing.
_spotify_fetch_mpris() {
  local dest=org.mpris.MediaPlayer2.spotify obj=/org/mpris/MediaPlayer2
  local iface=org.mpris.MediaPlayer2.Player state meta
  state=$(busctl --user --json=short get-property $dest $obj $iface PlaybackStatus 2>/dev/null) || return
  [[ $state == *'"Playing"'* ]] || return
  meta=$(busctl --user --json=short get-property $dest $obj $iface Metadata 2>/dev/null) || return
  if (( $+commands[jq] )); then
    jq -r '.data as $m | (($m["xesam:artist"].data // []) | join(", ")) + " - " + ($m["xesam:title"].data // "")' <<<$meta
  elif (( $+commands[python3] )); then
    python3 -I -c 'import json, sys
m = json.load(sys.stdin)["data"]
print(", ".join(m.get("xesam:artist", {}).get("data", [])) + " - " + m.get("xesam:title", {}).get("data", ""))' <<<$meta
  fi
}

# Runs in a background job; writes result to the cache file
_spotify_fetch() {
  local out
  if (( $+commands[osascript] )); then
    out=$(osascript 2>/dev/null <<'EOF'
if application "Spotify" is running then
  tell application "Spotify"
    if player state is playing then
      return (artist of current track) & " - " & (name of current track)
    end if
  end tell
end if
return ""
EOF
)
  elif (( $+commands[busctl] )); then
    out=$(_spotify_fetch_mpris)
  fi
  print -r -- "$out" > "$_spotify_cache"
}

# Fake equalizer: each bar random-walks one step per frame (smooth motion).
# Rendered as braille: one character holds two thin bars (heights 0-4).
_spotify_randomize_bars() {
  local -a left=(0 64 68 70 71) right=(0 128 160 176 184)
  local i h s="" hex
  for i in 1 2 3 4; do
    (( h = _spotify_heights[i] + RANDOM % 3 - 1 ))
    (( h < 1 )) && h=1
    (( h > 4 )) && h=4
    _spotify_heights[i]=$h
  done
  for i in 1 3; do
    hex=${(l:4::0:)$(( [##16] 0x2800 + left[_spotify_heights[i] + 1] + right[_spotify_heights[i + 1] + 1] ))}
    print -v hex -- "\u$hex"
    s+=$hex
  done
  SPOTIFY_BARS=$s
}

# Build the styled prompt segment from current state
_spotify_build_segment() {
  if [[ -n $SPOTIFY_NOW ]]; then
    local text=$SPOTIFY_NOW
    (( ${#text} > 40 )) && text="${text[1,39]}…"
    if (( SPOTIFY_ROUNDED )); then
      SPOTIFY_SEGMENT="%F{${_spotify_bg}}"$''"%K{${_spotify_bg}}%F{${_spotify_fg}} ${SPOTIFY_BARS} ♪ ${text} %k%F{${_spotify_bg}}"$''"%f"
    else
      SPOTIFY_SEGMENT="%K{${_spotify_bg}}%F{${_spotify_fg}} ${SPOTIFY_BARS} ♪ ${text} %f%k"
    fi
  else
    SPOTIFY_SEGMENT=""
  fi
}

# Read the cache file written by the background fetch, then start a new fetch
_spotify_refresh_track() {
  [[ -r $_spotify_cache ]] && SPOTIFY_NOW="$(<$_spotify_cache)"
  SPOTIFY_NOW="${SPOTIFY_NOW//\%/%%}"        # escape % for prompt expansion
  (_spotify_fetch &) 2>/dev/null             # fire and forget, no job noise
}

# zle calls this when the ticker pipe is readable
_spotify_on_tick() {
  local fd=$1 line before=$SPOTIFY_SEGMENT
  if [[ -n $2 && $2 != zle ]]; then          # pipe closed or errored
    zle -F $fd
    exec {fd}<&-
    _spotify_fd=""
    return
  fi
  read -r -u $fd -t 1 line 2>/dev/null

  (( ++_spotify_frame ))
  local -i every=$(( SPOTIFY_NOW_INTERVAL / SPOTIFY_BARS_INTERVAL ))
  (( every < 1 )) && every=1
  (( _spotify_frame % every == 0 )) && _spotify_refresh_track

  [[ -n $SPOTIFY_NOW ]] && _spotify_randomize_bars
  _spotify_build_segment
  [[ $SPOTIFY_SEGMENT != $before ]] && zle reset-prompt
}

_spotify_ticker_start() {
  [[ -n $_spotify_fd ]] && return
  local -i centis=$(( SPOTIFY_BARS_INTERVAL * 100 ))
  (( centis < 1 )) && centis=1
  exec {_spotify_fd}< <(
    while true; do
      print -r -- t || exit
      if (( $+builtins[zselect] )); then zselect -t $centis; else sleep $SPOTIFY_BARS_INTERVAL; fi
    done
  )
  zle -F $_spotify_fd _spotify_on_tick
}

_spotify_precmd() {
  _spotify_refresh_track
  _spotify_build_segment
  _spotify_ticker_start
}

_spotify_exit() {
  [[ -n $_spotify_fd ]] && exec {_spotify_fd}<&-
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _spotify_precmd
add-zsh-hook zshexit _spotify_exit
