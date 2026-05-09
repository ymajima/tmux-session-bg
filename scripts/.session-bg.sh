#!/bin/sh

set -u

DEFAULT_BG="${DEFAULT_BG:-#303030}"
SATURATION="${SATURATION:-55}"
BASE_LIGHTNESS="${BASE_LIGHTNESS:-24}"
LIGHTNESS_STEP="${LIGHTNESS_STEP:-7}"
MIN_LIGHTNESS="${MIN_LIGHTNESS:-20}"
MAX_LIGHTNESS="${MAX_LIGHTNESS:-55}"
RGB_DARKEN_STEP="${RGB_DARKEN_STEP:-0.18}"
RGB_DARKEN_MAX_RATIO="${RGB_DARKEN_MAX_RATIO:-0.55}"

usage() {
  cat <<'EOF'
usage:
  session-bg.sh apply-client <tty> <session_name>
  session-bg.sh apply-all
  session-bg.sh reset-client <tty>
  session-bg.sh color <session_name>
EOF
}

parse_session_name() {
  session_name=$1

  printf '%s\n' "$session_name" | awk -F- '
    $0 ~ /^[A-Za-z]-[0-9]+-.+/ && NF >= 3 {
      prefix_len = length($1) + length($2) + 2
      name = substr($0, prefix_len + 1)
      if (name != "") {
        print tolower($1) "\t" $2
        found = 1
        exit
      }
    }
    END {
      if (!found) {
        exit 1
      }
    }
  '
}

base_rgb_for_letter() {
  letter=$1

  case "$letter" in
    p) printf '%s\n' '56 67 25' ;;
    w) printf '%s\n' '27 50 66' ;;
    c) printf '%s\n' '72 50 30' ;;
    *) return 1 ;;
  esac
}

rgb_for_index() {
  base_r=$1
  base_g=$2
  base_b=$3
  idx=$4

  awk \
    -v base_r="$base_r" \
    -v base_g="$base_g" \
    -v base_b="$base_b" \
    -v idx="$idx" \
    -v step="$RGB_DARKEN_STEP" \
    -v max_ratio="$RGB_DARKEN_MAX_RATIO" \
    'BEGIN {
      ratio = idx * step
      if (ratio < 0) {
        ratio = 0
      }
      if (ratio > max_ratio) {
        ratio = max_ratio
      }

      r = int(base_r * (1 - ratio) + 0.5)
      g = int(base_g * (1 - ratio) + 0.5)
      b = int(base_b * (1 - ratio) + 0.5)

      printf "#%02x%02x%02x\n", r, g, b
    }'
}

hue_for_letter() {
  letter=$1

  case "$letter" in
    p) printf '%s\n' 210 ;;
    w) printf '%s\n' 135 ;;
    *)
      printf '%s\n' "$letter" | awk '
        BEGIN {
          alphabet = "abcdefghijklmnopqrstuvwxyz"
        }
        {
          idx = index(alphabet, tolower($0))
          if (idx == 0) {
            exit 1
          }
          hue = int((((idx - 1) * 360) / 26) + 0.5)
          print hue
        }
      '
      ;;
  esac
}

lightness_for_index() {
  idx=$1

  awk \
    -v idx="$idx" \
    -v base="$BASE_LIGHTNESS" \
    -v step="$LIGHTNESS_STEP" \
    -v min="$MIN_LIGHTNESS" \
    -v max="$MAX_LIGHTNESS" \
    'BEGIN {
      lightness = base + (idx * step)
      if (lightness < min) {
        lightness = min
      }
      if (lightness > max) {
        lightness = max
      }
      print lightness
    }'
}

hsl_to_rgb() {
  hue=$1
  saturation=$2
  lightness=$3

  awk \
    -v h="$hue" \
    -v s="$saturation" \
    -v l="$lightness" \
    '
    function abs(value) {
      return value < 0 ? -value : value
    }
    function fmod(x, y) {
      return x - (y * int(x / y))
    }
    BEGIN {
      h = h + 0
      s = (s + 0) / 100
      l = (l + 0) / 100

      if (h < 0) {
        h = 0
      }
      if (h >= 360) {
        h = fmod(h, 360)
      }

      c = (1 - abs((2 * l) - 1)) * s
      hp = h / 60
      x = c * (1 - abs(fmod(hp, 2) - 1))

      r1 = 0
      g1 = 0
      b1 = 0

      if (hp < 1) {
        r1 = c; g1 = x; b1 = 0
      } else if (hp < 2) {
        r1 = x; g1 = c; b1 = 0
      } else if (hp < 3) {
        r1 = 0; g1 = c; b1 = x
      } else if (hp < 4) {
        r1 = 0; g1 = x; b1 = c
      } else if (hp < 5) {
        r1 = x; g1 = 0; b1 = c
      } else {
        r1 = c; g1 = 0; b1 = x
      }

      m = l - (c / 2)
      r = int(((r1 + m) * 255) + 0.5)
      g = int(((g1 + m) * 255) + 0.5)
      b = int(((b1 + m) * 255) + 0.5)

      printf "#%02x%02x%02x\n", r, g, b
    }'
}

color_for_session() {
  session_name=$1

  if ! fields=$(parse_session_name "$session_name"); then
    printf '%s\n' "$DEFAULT_BG"
    return 0
  fi

  old_ifs=$IFS
  IFS='	'
  set -- $fields
  IFS=$old_ifs

  letter=$1
  index=$2

  if base_rgb=$(base_rgb_for_letter "$letter"); then
    old_ifs=$IFS
    IFS=' '
    set -- $base_rgb
    IFS=$old_ifs
    if rgb_for_index "$1" "$2" "$3" "$index"; then
      return 0
    fi
    printf '%s\n' "$DEFAULT_BG"
    return 0
  fi

  if ! hue=$(hue_for_letter "$letter"); then
    printf '%s\n' "$DEFAULT_BG"
    return 0
  fi

  if ! lightness=$(lightness_for_index "$index"); then
    printf '%s\n' "$DEFAULT_BG"
    return 0
  fi

  if ! hsl_to_rgb "$hue" "$SATURATION" "$lightness"; then
    printf '%s\n' "$DEFAULT_BG"
    return 0
  fi
}

write_osc11() {
  tty_path=$1
  bg=$2

  case "$tty_path" in
    /dev/*) ;;
    *) return 0 ;;
  esac

  [ -w "$tty_path" ] || return 0

  printf '\033]11;%s\007' "$bg" >"$tty_path" 2>/dev/null || true
}

apply_client() {
  tty_path=$1
  session_name=$2
  bg=$(color_for_session "$session_name")
  write_osc11 "$tty_path" "$bg"
}

apply_all() {
  command -v tmux >/dev/null 2>&1 || return 1

  tmux list-clients -F '#{client_tty}	#{client_session}' 2>/dev/null |
    while IFS='	' read -r tty_path session_name; do
      [ -n "$tty_path" ] || continue
      bg=$(color_for_session "${session_name:-}")
      write_osc11 "$tty_path" "$bg"
    done
}

reset_client() {
  tty_path=$1
  write_osc11 "$tty_path" "$DEFAULT_BG"
}

command=${1:-}

case "$command" in
  apply-client)
    [ $# -eq 3 ] || {
      usage >&2
      exit 1
    }
    apply_client "$2" "$3"
    ;;
  apply-all)
    [ $# -eq 1 ] || {
      usage >&2
      exit 1
    }
    apply_all
    ;;
  reset-client)
    [ $# -eq 2 ] || {
      usage >&2
      exit 1
    }
    reset_client "$2"
    ;;
  color)
    [ $# -eq 2 ] || {
      usage >&2
      exit 1
    }
    color_for_session "$2"
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
