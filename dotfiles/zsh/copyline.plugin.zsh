# copyline — put the last line of terminal output on the clipboard.
#
#   !copy          copy the last non-empty line of the last command's output
#   !copy 5        copy the last 5 lines of it
#   !copy -h       usage
#
# `!copy` never reaches the parser — which would try history expansion on the
# `!` and fail with "event not found". An accept-line wrapper recognises it in
# the editing buffer and runs the copy instead of the line.
#
# Reading back what is already on screen needs a multiplexer, so the grab goes
# through `tmux capture-pane`. Outside tmux there is nothing to read and the
# widget says so rather than copying something else.

# 0 disables the desktop notification.
: ${COPYLINE_NOTIFY:=1}
# Most lines to look back through.
: ${COPYLINE_SCROLLBACK:=500}

# Text of the most recent successful grab, for scripts that want it.
typeset -g COPYLINE_TEXT=''

# Absolute pane row (history + screen) where the last command's output began.
# Recorded in preexec so `!copy` can tell output from the prompts around it:
# without the anchor, a command that printed nothing hands back its own prompt
# line. Absolute rather than screen-relative, so it survives scrolling.
typeset -g _copyline_out_row=''
typeset -ga _copyline_tgt=()

_copyline_preexec() {
  _copyline_out_row=''
  [[ -n $TMUX ]] && (( $+commands[tmux] )) || return 0
  _copyline_tgt=()
  [[ -n $TMUX_PANE ]] && _copyline_tgt=(-t $TMUX_PANE)
  # preexec runs after the newline is echoed, so the cursor already sits on
  # the first row this command can write to.
  _copyline_out_row=$(command tmux display-message -p $_copyline_tgt \
    '#{e|+:#{history_size},#{cursor_y}}' 2>/dev/null)
}
autoload -Uz add-zsh-hook
add-zsh-hook preexec _copyline_preexec

_copyline_clip() {
  local text=$1 copied=0 cmd

  # In tmux, load-buffer -w fills tmux's own paste buffer *and* forwards the
  # text to the terminal over OSC 52, which is what `set-clipboard on` is for.
  # That path also works over ssh, where no local clipboard tool would.
  if [[ -n $TMUX ]] && (( $+commands[tmux] )); then
    print -rn -- "$text" | command tmux load-buffer -w - 2>/dev/null && copied=1
  fi

  local -a tools=()
  [[ -n $WAYLAND_DISPLAY ]] && tools+=('wl-copy')
  [[ -n $DISPLAY ]] && tools+=('xclip -selection clipboard -in' 'xsel --clipboard --input')
  tools+=('pbcopy')
  for cmd in $tools; do
    (( $+commands[${cmd%% *}] )) || continue
    print -rn -- "$text" | ${=cmd} >/dev/null 2>&1 && { copied=1; break }
  done

  (( copied ))
}

# Grab the last $2 lines of the last command's output, falling back to the
# lines above the prompt marked by $1 when there is no anchor yet.
# Sets COPYLINE_TEXT. 0 = ok, 1 = nothing to copy, 2 = no multiplexer.
_copyline_grab() {
  setopt localoptions extendedglob
  local marker=$1 n=$2
  COPYLINE_TEXT=''

  [[ -n $TMUX ]] && (( $+commands[tmux] )) || return 2
  local -a tgt=()
  [[ -n $TMUX_PANE ]] && tgt=(-t $TMUX_PANE)

  local -a lines=()
  if [[ $_copyline_out_row == -#<-> ]]; then
    local -a now=( ${=$(command tmux display-message -p $tgt \
      '#{history_size} #{cursor_y}' 2>/dev/null)} )
    (( ${#now} == 2 )) || return 2
    # Screen-relative rows: 0 is the top of the visible pane, negative is
    # history. The region runs from the first row of output to the row above
    # the prompt we are standing on.
    local start=$(( _copyline_out_row - now[1] )) end=$(( now[2] - 1 ))
    (( start > end )) && return 1
    (( start < end - COPYLINE_SCROLLBACK )) && start=$(( end - COPYLINE_SCROLLBACK ))
    lines=( "${(@f)$(command tmux capture-pane -p -J $tgt -S $start -E $end 2>/dev/null)}" )
  else
    # No command has run in this shell yet: take the screen and drop the
    # prompt we were invoked from. Search upwards, so an older !copy sitting
    # in the scrollback loses to the current one.
    lines=( "${(@f)$(command tmux capture-pane -p -J $tgt -S -$COPYLINE_SCROLLBACK 2>/dev/null)}" )
    local i mark=0
    for (( i = ${#lines}; i > 0; i-- )); do
      if [[ ${lines[i]} == *"$marker"* ]]; then
        mark=$i
        break
      fi
    done
    (( mark > 0 )) || mark=${#lines}
    lines=( "${(@)lines[1,mark-1]}" )
  fi

  # capture-pane pads short rows, so "blank" trailing lines are runs of spaces.
  while (( ${#lines} > 0 )) && [[ -z ${lines[-1]//[[:space:]]/} ]]; do
    lines=( "${(@)lines[1,-2]}" )
  done
  (( ${#lines} > 0 )) || return 1

  (( n > ${#lines} )) && n=${#lines}
  lines=( "${(@)lines[-n,-1]}" )
  lines=( "${(@)lines%%[[:space:]]##}" )
  COPYLINE_TEXT=${(pj:\n:)lines}
  return 0
}

_copyline_notify() {
  (( COPYLINE_NOTIFY )) || return 0
  (( $+commands[notify-send] )) || return 0
  notify-send -a copyline -t 2500 -i edit-copy -- "$1" "$2" >/dev/null 2>&1 &!
}

# One-line preview, ellipsised: fits a zle message or a toast.
_copyline_preview() {
  local text=$1 first=${1%%$'\n'*} extra=0
  [[ $text == *$'\n'* ]] && extra=$(( ${#${(f)text}} - 1 ))
  (( ${#first} > 100 )) && first="${first[1,99]}…"
  (( extra > 0 )) && first="$first (+$extra more)"
  print -r -- "$first"
}

# The work itself. Prints its result; the widget relays that through zle -M.
copyline() {
  emulate -L zsh
  setopt extendedglob
  local marker=copyline n=1 quiet=0

  while (( $# )); do
    case $1 in
      -h|--help)
        print -r -- 'usage: !copy [N]   copy the last N (default 1) lines of output'
        return 0 ;;
      -m) marker=$2; shift ;;
      -q) quiet=1 ;;
      <->) n=$1 ;;
      *) print -ru2 -- "copyline: unknown argument: $1"; return 2 ;;
    esac
    shift
  done
  (( n > 0 )) || n=1

  _copyline_grab "$marker" $n
  case $? in
    2) print -ru2 -- 'copyline: needs tmux — nothing to read the screen back from'
       return 1 ;;
    1) print -ru2 -- 'copyline: no output above the prompt to copy'
       return 1 ;;
  esac

  if ! _copyline_clip "$COPYLINE_TEXT"; then
    print -ru2 -- 'copyline: no clipboard tool (wl-copy, xclip, xsel, pbcopy)'
    return 1
  fi

  local preview=$(_copyline_preview "$COPYLINE_TEXT")
  _copyline_notify 'Copied to clipboard' "$preview"
  (( quiet )) || print -r -- "copied: $preview"
  return 0
}

_copyline_accept_line() {
  setopt localoptions extendedglob

  local trimmed=${${BUFFER##[[:space:]]#}%%[[:space:]]#}
  if [[ $trimmed == '!copy' || $trimmed == '!copy '* ]]; then
    local -a args=( ${=trimmed#!copy} )
    # The marker is the text as it appears on screen, so the fallback grab can
    # find this prompt row and start looking above it.
    local out=$(copyline -m "$trimmed" $args 2>&1)
    BUFFER=''
    CURSOR=0
    zle -M "${out:-copyline: nothing to report}"
    return 0
  fi

  if (( $+widgets[_copyline_orig_accept_line] )); then
    zle _copyline_orig_accept_line
  else
    zle .accept-line
  fi
}

# Wrap whatever accept-line is bound now, so plugins that installed their own
# (atuin, autosuggestions) keep working.
() {
  local prev=${widgets[accept-line]}
  case $prev in
    user:_copyline_accept_line) return 0 ;;
    user:*) zle -N _copyline_orig_accept_line "${prev#user:}" ;;
  esac
  zle -N accept-line _copyline_accept_line
}
