#!/usr/bin/env bash
# Claude Code status line: model | context | 5h limit | 7d limit | cost and tokens, right-aligned.
# Reads the status JSON on stdin. Extracted unchanged from the inline command in settings.json.

input=$(cat)

m=$(echo "$input" | jq -r '.model.display_name')
c=$(echo "$input" | jq -r '(.context_window.used_percentage // 0) | floor')
s=$(echo "$input" | jq -r '(.rate_limits.five_hour.used_percentage // empty) | floor')
w=$(echo "$input" | jq -r '(.rate_limits.seven_day.used_percentage // empty) | floor')
r=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# Time left until the 5h window resets, e.g. " 2h05m", " 42m", " <1m".
left=''
case "$r" in
  '' | *[!0-9]*) ;;
  *)
    now=$(date +%s)
    rem=$((r - now))
    [ $rem -lt 0 ] && rem=0
    if [ $rem -eq 0 ]; then
      left=' 0m'
    elif [ $rem -lt 60 ]; then
      left=' <1m'
    else
      h=$((rem / 3600))
      mi=$(((rem % 3600) / 60))
      if [ $h -gt 0 ]; then
        mm=$mi
        [ $mi -lt 10 ] && mm=0$mi
        left=" ${h}h${mm}m"
      else
        left=" ${mi}m"
      fi
    fi
    ;;
esac

# Time left until the 7d window resets, e.g. " 3d", " 5h", " <1h".
wr=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
wleft=''
case "$wr" in
  '' | *[!0-9]*) ;;
  *)
    wnow=$(date +%s)
    wrem=$((wr - wnow))
    [ $wrem -lt 0 ] && wrem=0
    if [ $wrem -ge 86400 ]; then
      wleft=" $((wrem / 86400))d"
    elif [ $wrem -ge 3600 ]; then
      wleft=" $((wrem / 3600))h"
    elif [ $wrem -eq 0 ]; then
      wleft=' 0h'
    else
      wleft=' <1h'
    fi
    ;;
esac

# 10-segment bar, green to red, followed by the percentage.
bar() {
  p=$1
  f=$(((p + 5) / 10))
  [ $f -gt 10 ] && f=10
  b=''
  i=1
  while [ $i -le 10 ]; do
    if [ $i -le $f ]; then
      case $i in
        1) n=46 ;;
        2) n=82 ;;
        3) n=118 ;;
        4) n=154 ;;
        5) n=190 ;;
        6) n=226 ;;
        7) n=220 ;;
        8) n=208 ;;
        9) n=202 ;;
        *) n=196 ;;
      esac
      d=$(printf '\033[38;5;%sm▰\033[0m' "$n")
    else
      d=$(printf '\033[38;5;240m▱\033[0m')
    fi
    b="${b}$d"
    i=$((i + 1))
  done
  printf '%s %s%%' "$b" "$p"
}

# Compact token count: 950, 12k, 1.4M.
fmt() {
  n=$1
  if [ "$n" -ge 1000000 ]; then
    printf '%s.%sM' $((n / 1000000)) $(((n % 1000000) / 100000))
  elif [ "$n" -ge 1000 ]; then
    printf '%sk' $((n / 1000))
  else
    printf '%s' "$n"
  fi
}

ct=$(echo "$input" | jq -r '(.context_window.total_input_tokens // 0) | floor')
case "$ct" in '' | *[!0-9]*) ct=0 ;; esac

l1=$(printf '\033[36m%s\033[0m' "$m")

cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
cost=$(LC_NUMERIC=C printf '%.2f' "$cost" 2>/dev/null)
case "$cost" in '' | *[!0-9.]*) cost=0.00 ;; esac

tok=''
ot=$(echo "$input" | jq -r '(.context_window.total_output_tokens // 0) | floor')
case "$ot" in '' | *[!0-9]*) ot=0 ;; esac
if [ "$ct" -gt 0 ] || [ "$ot" -gt 0 ]; then
  if [ "$ot" -ge 1000 ] && [ "$ot" -le 9999 ]; then
    otx=$(printf '%s.%sk' $((ot / 1000)) $(((ot % 1000) / 100)))
  else
    otx=$(fmt "$ot")
  fi
  tok=" ↑$(fmt "$ct") ↓$otx"
fi

l1="$l1 | 🧠 $(bar "$c")"
if [ -n "$s" ]; then l1="$l1 | 🗒️ $(bar "$s")$left"; fi
if [ -n "$w" ]; then l1="$l1 | 📆 $(bar "$w")$wleft"; fi
l1="$l1 | 💰 \$$cost$tok"

# Terminal width: ask the tty, then $COLUMNS, then 120.
cols=$({ stty size </dev/tty; } 2>/dev/null | cut -d' ' -f2)
case "$cols" in '' | *[!0-9]*) cols=${COLUMNS:-120} ;; esac
case "$cols" in '' | *[!0-9]*) cols=120 ;; esac

esc=$(printf '\033')

# Print $1 right-aligned: pad with spaces by its visible width (ANSI stripped, wide emoji counted as 2).
rpad() {
  plain=$(printf '%s' "$1" | sed "s/${esc}\[[0-9;]*m//g")
  vis=$(printf '%s' "$plain" | python3 -c 'import sys,unicodedata as u;t=sys.stdin.buffer.read().decode("utf-8","ignore");print(sum(0 if u.category(c) in ("Mn","Me","Cf") else 2 if u.east_asian_width(c) in ("W","F") or ord(c)>=0x1f000 else 1 for c in t))' 2>/dev/null)
  case "$vis" in
    '' | *[!0-9]*)
      # No python3: approximate with the character count plus one extra column per emoji.
      vis=$(printf '%s' "$plain" | LC_ALL=C.UTF-8 wc -m | tr -d ' ')
      case "$vis" in '' | *[!0-9]*) vis=0 ;; esac
      vis=$((vis + $(printf '%s' "$plain" | grep -Eo '💰|🧠|📆' | wc -l)))
      ;;
  esac
  pad=$((cols - vis - 2))
  [ "$pad" -lt 0 ] && pad=0
  printf "%${pad}s" ''
  printf '%s' "$1"
}

rpad "$l1"

