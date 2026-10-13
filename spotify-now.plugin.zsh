# spotify-now: Spotify now-playing segment with animated equalizer bars (macOS).
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
: ${SPOTIFY_NOW_INTERVAL:=5}        # seconds between track refreshes
: ${SPOTIFY_ROUNDED:=1}             # 1 = rounded caps (needs a Nerd Font), 0 = square box

zmodload zsh/zselect 2>/dev/null    # fork-free sub-second waits

# Runs in a background job; writes result to the cache file
_spotify_fetch() {
  local out
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
      SPOTIFY_SEGMENT="%F{35}"$''"%K{35}%F{black} ${SPOTIFY_BARS} ♪ ${text} %k%F{35}"$''"%f"
    else
      SPOTIFY_SEGMENT="%K{35}%F{black} ${SPOTIFY_BARS} ♪ ${text} %f%k"
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
